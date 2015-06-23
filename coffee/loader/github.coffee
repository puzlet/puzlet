#--- GitHub/Gist ---#

console.log "GitHub/Gist"

dependencies = [
  {url: "//ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/themes/smoothness/jquery-ui.css"}
  {url: "//ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/jquery-ui.min.js"}
  {url: "/puzlet/puzlet/css/github.css"}
  {url: "/puzlet/puzlet/js/jquery.cookie.js"}
]

$blab?.resources?.on "preload", (data, done) ->
  # Initiate GitHub object and load Gist files - these override blab files.
  $blab.load dependencies, -> new GitHub $blab.resources, done

$blab?.resources?.on "ready", ->
  container = $ ".github-save"
  new SaveButton(container, -> $.event.trigger "saveGitHub") if container.length


class GitHub
  
  constructor: (@resources, callback) ->
    
    @setCredentials()  # None initially
    
    @gist = new Gist
      resources: @resources 
      getUsername: => if @auth then @username else null
      authBeforeSend: (xhr) => @authBeforeSend(xhr)
      callback: callback
      
    @repo = new Repo
      resources: @resources
      getUsername: => if @auth then @username else null
      authBeforeSend: (xhr) => @authBeforeSend(xhr)
      
    $(document).on "saveGitHub", =>
      $.event.trigger "preSaveResources"
      @save()
      
  save: (callback) ->
    
    if @credentialsForm
      @credentialsForm.open()
      return
    
    @credentialsForm = new CredentialsForm
      setCredentials: (username, key) => @setCredentials username, key
      isRepoMember: (cb) => @repo.isRepoMember cb
      updateRepo: (callback) => @repo.commitChangedResourcesToRepo(callback)
      saveAsGist: (callback) => @gist.save(callback)
  
  setCredentials: (@username, @key) ->
    
    make_base_auth = (user, password) ->
      tok = user + ':' + password
      hash = btoa(tok)
      "Basic " + hash
    
    if @username and @key
      @auth = make_base_auth @username, @key
    
  authBeforeSend: (xhr) ->
    return unless @auth
    console.log "Set request header", @auth
    xhr.setRequestHeader('Authorization', @auth)


class Gist
  
  api: "https://api.github.com/gists"
  
  constructor: (@spec) ->
    {@resources, @getUsername, @authBeforeSend, @callback} = @spec
    @id = @getId()
    @apiId = => "#{@api}/#{@id}"
    @query = => "?gist=#{@id}"
    @load @callback
  
  load: (callback) ->
    unless @id
      @data = null
      callback?()
      return
    $.get(@apiId(), (@data) =>
      console.log "Gist loaded", @data
      @gistOwner = @data.owner?.login
      @resources.sourceMethod (url) => @data.files?[url]?.content ? null
      callback?()
    )
  
  save: (callback) ->
    
    @username = @getUsername()
    console.log "Save as Gist (#{@username ? 'anonymous'})"
    
    resources = @resources.select (resource) -> resource.inBlab()
    @files = {}
    for resource in resources
      content = resource.content
      @files[resource.url] = {content: content} if content and content isnt "\n"
    
    if @id and @username
      if @username is @gistOwner
        # Edit current user's Gist.
        @edit(callback)
      else
        # Fork Gist (different user).
        @forkAndEdit()
    else
      # Create new Gist if blab is not from a Gist or if anonymous user (no credentials).
      @create()
      
  ajaxData: ->
    ajaxDataObj =
      description: @description()
      public: false
      files: @files
    ajaxData = JSON.stringify(ajaxDataObj)
  
  create: ->
    $.ajax
      type: "POST"
      url: @api
      data: @ajaxData()
      beforeSend: (xhr) => @authBeforeSend(xhr)
      success: (data) =>
        console.log "Created Gist", data
        @id = data.id
        if @username
          @setDescription => @redirect()
        else
          @redirect()
      dataType: "json"
  
  forkAndEdit: ->
    console.log "Fork..."
    @fork (data) => 
      @id = data.id 
      @patch @ajaxData(), (=> @redirect())
#      setTimeout (=> @patch @ajaxData(), (=> @redirect())), 100  # Fix bug?
      
  edit: (callback) ->
    @patch @ajaxData(), =>
      resource.edited = false for resource in @resources
      callback?()
      $.event.trigger "codeSaved"
  
  patch: (ajaxData, callback) ->
    $.ajax
      type: "PATCH"
      url: @apiId()
      data: ajaxData
      beforeSend: (xhr) => @authBeforeSend(xhr)
      success: (data) ->
        console.log "Updated Gist", data
        callback?()
      dataType: "json"
    
  fork: (callback) ->
    $.ajax
      type: "POST"
      url: "#{@apiId()}/forks"
      beforeSend: (xhr) => @authBeforeSend(xhr)
      success: (data) =>
        console.log "Forked Gist", data
        callback?(data)
      dataType: "json"
      
  setDescription: (callback) ->
    ajaxData = JSON.stringify(description: @description())
    @patch ajaxData, callback
  
  description: ->
    description = document.title
    description += " [#{@blabUrl()}]" if @id  # This might use localhost in description
    description
  
  redirect: ->
    window.location = @blabUrl()
    
  blabUrl: ->
    l = window.location
    [l.protocol, '//', l.host, l.pathname, @query()].join('')
  
  getId: ->
    @a = document.createElement "a"
    @a.href = window.location.href
    @search = @a.search
    # ZZZ dup code - should really extend to get general URL params.
    @query = @search?.slice(1)
    return null unless @query
    h = @query.split "&"
    p = h?[0].split "="
    if p.length and p[0] is "gist" then p[1] else null    


class Repo
  
  ghApi: "https://api.github.com/repos/puzlet"  # Currently works only for puzlet.org (or localhost for testing).
  ghMembersApi: "https://api.github.com/orgs/puzlet/members"
  
  constructor: (@spec) ->
    
    {@resources, @getUsername, @authBeforeSend} = @spec
    # ZZZ note getUsername ...
    
    @blabLocation = @resources.blabLocation  # ZZZ to fix
    @hostname = @blabLocation?.host  # ZZZ to fix
    @blabId = @blabLocation?.repo  # ZZZ to fix
      
  repoApiUrl: (path) ->
    "#{@ghApi}/#{@blabId}/contents/#{path}"
  
  commitChangedResourcesToRepo: (callback) ->
    unless @hostname is "puzlet.org" or @hostname is "localhost" and @username and @key
      console.log("Can commit changes only to puzlet.org repo, and only with credentials.")
      return
    resources = @resources.select (resource) -> resource.edited
    console.log "resources", resources
    return unless resources.length
    maxIdx = resources.length-1
    commit = (idx) =>
      if idx>maxIdx
        callback?()
        $.event.trigger "codeSaved"
        return
      resource = resources[idx]
      @loadResourceFromRepo(resource, (data) =>
        resource.sha = data.sha
        @commitResourceToRepo resource, ->
          resource.edited = false
          commit(idx+1)  # Recursion
      )
    commit(0)
    
  loadResourceFromRepo: (resource, callback) ->
    # ZZZ Can resources be loaded earlier?
    path = resource.url
    url = @repoApiUrl path
    $.get(url, (data) =>
      console.log "Loaded resource #{path} from repo", data
      callback?(data)
    )
    
  commitResourceToRepo: (resource, callback) ->
    
    path = resource.url
    url = @repoApiUrl path
    
    ajaxData =
      message: "Puzlet commit"
      path: path
      content: btoa(resource.content) # Base 64
      sha: resource.sha  # Fetched from GitHub
      # Optional: committer
  
    $.ajax
      type: "PUT"
      url: url  
      data: JSON.stringify(ajaxData)
      beforeSend: (xhr) => @authBeforeSend(xhr)
      success: (data) =>
        console.log "Updated repo file", data
        callback?(data)
      dataType: "json"
  
  getRepoMembers: (callback) ->
    $.ajax
      type: "GET"
      url: @ghMembersApi
      beforeSend: (xhr) => @authBeforeSend(xhr)
      success: (data) -> callback?(data)
      dataType: "json"
  
  isRepoMember: (callback) ->
    @cacheIsRepoMember ?= {}
    callback(@cacheIsRepoMember[@username]) if @cacheIsRepoMember[@username]?
    # ZZZ way to do this with direct ajax call?
    set = (isMember) =>
      @cacheIsRepoMember[@username] = isMember if @username
      callback isMember
    unless @blabId and @username and @key
      set false
      return
    found = false
    @getRepoMembers (members) =>
      for member in members
        found = @username is member.login
        if found
          set true
          return
    set(false)


class CredentialsForm
  
  constructor: (@spec) ->
    
    #@blabId = @spec.blabId  # ZZZ not needed?
    
    @username = $.cookie("gh_user")
    @key = $.cookie("gh_key")
    
    @dialog = $ "<div>",
      id: "github_save_dialog"
      title: "Save immediately, or enter credentials."
    
    @dialog.dialog
      autoOpen: false
      height: 500
      width: 500
      modal: true
      close: => @form[0].reset()
    
    @spec.setCredentials @username, @key
    @setButtons()
    
    @form = $ "<form>",
      id: "github_save_form"
      submit: (evt) => evt.preventDefault()
        
    @dialog.append @form
    
    @usernameField()
    @keyField()
    @infoText()
    @saving = $ "<p>",
      text: "Saving..."
      css:
        fontSize: "16pt"
        color: "green"
    @dialog.append @saving
    @saving.hide()
    
    @open()
    
  open: ->
    @usernameInput.val @username
    @keyInput.val @key
    @setButtons()
    @dialog.dialog "open"
    
  usernameField: ->
    id = "username"
    label = $ "<label>",
      "for": id
      text: "Username"
      
    @usernameInput = $ "<input>",
      name: "username"
      id: id
      value: @username
      class: "text ui-widget-content ui-corner-all"
      change: => @setCredentials()
      
    @form.append(label).append(@usernameInput)
    
  keyField: ->
    id = "key"
    label = $ "<label>",
      "for": id
      text: "Personal access token"
    
    @keyInput = $ "<input>",
      type: "password"
      name: "key"
      id: id
      value: @key
      class: "text ui-widget-content ui-corner-all"
      change: => @setCredentials()
      
    @form.append(label).append(@keyInput)
    
  infoText: ->
    @dialog.append """
    <br>
    <p>To save under your GitHub account, enter your GitHub username and personal access token.
    You can generate your personal access token <a href='https://github.com/settings/applications' target='_blank'>here</a>.
    </p>
    <p>
    To save as <i>anonymous</i> Gist, continue without credentials.
    </p>
    <p>
    Your GitHub username and personal access token will be saved as cookies for future saves.
    To remove these cookies, clear the credentials above.
    </p>
    """
    
  setCredentials: ->
    console.log "Setting credentials and updating cookies"
    @username = if @usernameInput.val() isnt "" then @usernameInput.val() else null
    @key = if @keyInput.val() isnt "" then @keyInput.val() else null
    $.cookie("gh_user", @username) 
    $.cookie("gh_key", @key)
    @spec.setCredentials @username, @key
    @setButtons()
  
  setButtons: ->
    
    saveAction = =>
      @setCredentials()
      @saving.show()
      
    done = =>
      @saving.hide()
      @form[0].reset()
      @dialog.dialog("close")
    
    buttons =
      "Update repo": =>
        saveAction()
        @spec.updateRepo -> done()
      "Save as Gist": =>
        saveAction()
        @spec.saveAsGist -> done()
      Cancel: => @dialog.dialog("close")
    
    sel = (n) ->
      o = {}
      idx = 0
      for p, v of buttons
        o[p] = v if idx>=n
        idx++
      o
    
    @dialog.dialog buttons: sel(1)
    @spec.isRepoMember? (isMember) => (@dialog.dialog buttons: sel(0) if isMember)


class SaveButton
  
  constructor: (@container, @callback) ->
    
    @div = $ "<div>",
      id: "save_button_container"
      css:
        position: "fixed"
        top: 10
        right: 10
    
    @b = $ "<button>",
      text: "Save"
      click: =>
        @b.hide?()
        @callback?()
      title: "When you're done editing, save your changes to GitHub."
    
    # ZZZ no longer used
    @savingMessage = $ "<span>",
      css:
        top: 20
        color: "#2a2"
        cursor: "default"
      text: "Saving..."
    
    @div.append(@b).append(@savingMessage)
    @container.append @div
    
    # Hide initially
    @b.hide()
    @savingMessage.hide()
    
    $(document).on "codeNodeChanged", => @b.show()
    
    @b.button?(label: "Save")
    
  saving: ->
    @b.hide()
    @savingMessage.show()
