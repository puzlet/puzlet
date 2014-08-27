class Resource
	
	constructor: (@spec) ->
		# ZZZ option to pass string for url
		@url = @spec.url
		@var = @spec.var  # window variable name  # ZZZ needed here?
		@fileExt = @spec.fileExt ? Resource.getFileExt @url
		@loaded = false
		@head = document.head
		@containers = new ResourceContainers this
	
	load: (callback, type="text") ->
		# Default file load method.
		# Uses jQuery.
		if @spec.gistSource
			@content = @spec.gistSource
			@postLoad callback
			return
		success = (data) =>
			@content = data
			@postLoad callback
		t = Date.now()
		$.get(@url+"?t=#{t}", success, type)
			
	postLoad: (callback) ->
		@loaded = true
		callback?()
	
	isType: (type) -> @fileExt is type
	
	update: (@content) ->
		console.log "No update method for #{@url}"
	
	updateFromContainers: ->
		@containers.updateResource()
	
	hasEval: -> @containers.evals().length
	
	render: -> @containers.render()
	
	getEvalContainer: -> @containers.getEvalContainer()
	
	@getFileExt: (url) ->
		a = document.createElement "a"
		a.href = url
		fileExt = (a.pathname.match /\.[0-9a-z]+$/i)[0].slice(1)
	
	@typeFilter: (types) ->
		(resource) ->
			if typeof types is "string"
				resource.isType types
			else
				# Array of strings
				for type in types
					return true if resource.isType type
				false


class ResourceContainers
	
	# <div> attribute names for source and eval nodes. 
	fileContainerAttr: "data-file"
	evalContainerAttr: "data-eval"
	
	constructor: (@resource) ->
		@url = @resource.url
	
	render: ->
		@fileNodes = (new Ace.EditorNode $(node), @resource for node in @files())
		@evalNodes = (new Ace.EvalNode $(node), @resource for node in @evals())
		$pz.codeNode ?= {}
		$pz.codeNode[file.editor.id] = file.editor for file in @files
		
	getEvalContainer: ->
		# Get eval container if there is one (and only one).
		return null unless @evalNodes?.length is 1
		@evalNodes[0].container
		
	updateResource: ->
		console.log "Potential update issue because more than one editor for a resource", @resource if @fileNodes.length>1
		for fileNode in @fileNodes
			@resource.update(fileNode.code())
	
	files: -> $("div[#{@fileContainerAttr}='#{@url}']")
	
	evals: -> $("div[#{@evalContainerAttr}='#{@url}']")


class HtmlResource extends Resource
	
	update: (@content) ->
		$pz.renderHtml()


class ResourceInline extends Resource
	
	# Abstract class.
	# Subclass defines properties tag and mime.
	
	load: (callback) ->
		super =>
			@createElement()
			callback?()
			
	createElement: ->
		@element = $ "<#{@tag}>",
			type: @mime
			"data-url": @url
		@element.text @content
	
	inDom: ->
		$("#{@tag}[data-url='#{@url}']").length
		
	appendToHead: ->
		@head.appendChild @element[0] unless @inDom()
		
	update: (@content) ->
		@head.removeChild @element[0]
		@createElement()
		@appendToHead()
	
class CssResourceInline extends ResourceInline
	
	tag: "style"
	mime: "text/css"



class CssResourceLinked extends Resource
	
	load: (callback) ->
		@style = document.createElement "link"
		@style.setAttribute "type", "text/css"
		@style.setAttribute "rel", "stylesheet"
		t = Date.now()
		@style.setAttribute "href", @url  #+"?t=#{t}"
		#@style.setAttribute "data-url", @url
		
		# Old browsers (e.g., old iOS) don't support onload for CSS.
		# And so we force postLoad even before CSS loaded.
		# Forcing postLoad generally ok for CSS because won't affect downstream dependencies (unlike JS). 
		setTimeout (=> @postLoad callback), 0
		#@style.onload = => @postLoad callback
		
		@head.appendChild @style


class JsResourceInline extends ResourceInline
	
	tag: "script"
	mime: "text/javascript"


class JsResourceLinked extends Resource
	
	load: (callback) ->
		if @var and window[@var]
			console.log "Already loaded", @url
			# ZZZ postload?
			return
		@wait = true
		@script = document.createElement "script"
		@script.setAttribute "type", "text/javascript"
		@head.appendChild @script
		@script.onload = => @postLoad callback
		
		t = Date.now()
		# ZZZ need better way to handle caching
		cache = @url.indexOf("/puzlet/js") isnt -1 or @url.indexOf("http://") isnt -1
		@script.setAttribute "src", @url+(if cache then "" else "?t=#{t}")
		#@script.setAttribute "data-url", @url


class CoffeeResource extends Resource
	
	load: (callback) ->
		super =>
			@Compiler = if @hasEval() then CoffeeCompilerEval else CoffeeCompiler
			@compiler = new @Compiler @url
			callback?()
			
	compile: ->
		$blab.evaluatingResource = this
		@compiler.compile @content
		@resultStr = @compiler.resultStr
		$.event.trigger("compiledCoffeeScript", {url: @url})
	
	update: (@content) -> @compile()


class JsonResource extends Resource


class Resources
	
	# The resource type if based on:
	#   * file extension (html, css, js, coffee, json, py, m)
	#   * url path (in blab or external).
	# Ajax-loaded resources:
	#   * Any resource in current blab.
	#   * html, coffee, json, py, m resources.
	# For ajax-loaded resources, source is available for in-browser editing.
	# All other resources are "linked" resources - loaded via <link href=...> or <script src=...>.
	# load method specifies resources to load (via filter):
	#   * linked resources are appended to DOM as soon as they are loaded.
	#   * ajax-loaded resources (js, css) are appended after all resources loaded (for call to load).
	resourceTypes:
		html: {blab: HtmlResource, ext: HtmlResource}
		css: {blab: CssResourceInline, ext: CssResourceLinked}
		js: {blab: JsResourceInline, ext: JsResourceLinked}
		coffee: {blab: CoffeeResource, ext: CoffeeResource}
		json: {blab: JsonResource, ext: JsonResource}
		py: {blab: Resource, ext: Resource}
		m: {blab: Resource, ext: Resource}
	
	constructor: ->
		@resources = []
		
	add: (resourceSpecs) ->
		resourceSpecs = [resourceSpecs] unless resourceSpecs.length
		newResources = []
		for spec in resourceSpecs
			resource = @createResource spec
			newResources.push resource
			@resources.push resource
		if newResources.length is 1 then newResources[0] else newResources
		
	createResource: (spec) ->
		if spec.url
			url = spec.url
			fileExt = Resource.getFileExt url
		else
			for p, v of spec
				# Currently handles only one property.
				url = v
				fileExt = p
		spec = {url: url, fileExt: fileExt}
		location = if url.indexOf("/") is -1 then "blab" else "ext"
		spec.location = location  # Needed for coffee compiling
		spec.gistSource = @gistFiles?[url]?.content ? null
		if @resourceTypes[fileExt] then new @resourceTypes[fileExt][location](spec) else null
		
	load: (filter, loaded) ->
		# When are resources added to DOM?
		#   * Linked resources: as soon as they are loaded.
		#   * Inline resources (with appendToHead method): *after* all resources are loaded.
		filter = @filterFunction filter
		resources = @select((resource) -> not resource.loaded and filter(resource))
		if resources.length is 0
			loaded?()
			return
		resourcesToLoad = 0
		resourceLoaded = (resource) =>
			resourcesToLoad--
			if resourcesToLoad is 0
				@appendToHead filter  # Append to head if the appendToHead method exists for a resource, and if not aleady appended.
				loaded?()
		for resource in resources
			resourcesToLoad++
			resource.load -> resourceLoaded(resource)
	
	loadUnloaded: (loaded) ->
		# Loads all unloaded resources.
		@load (-> true), loaded
		
	appendToHead: (filter) ->
		filter = @filterFunction filter
		resources = @select((resource) -> not resource.inDom?() and resource.appendToHead? and filter(resource))
		resource.appendToHead() for resource in resources
		
	select: (filter) ->
		filter = @filterFunction filter
		(resource for resource in @resources when filter(resource))
		
	filterFunction: (filter) ->
		if typeof filter is "function" then filter else Resource.typeFilter(filter)
		
	find: (url) ->
		return resource for resource in @resources when resource.url is url
		return null
	
	render: ->
		resource.render() for resource in @resources
	
	setGistResources: (@gistFiles) ->
	
	updateFromContainers: ->
		for resource in @resources
			resource.updateFromContainers() if resource.edited


#--- CoffeeScript compiler/evaluator ---#

class CoffeeCompiler
	
	constructor: (@url) ->
		@head = document.head
	
	compile: (@content) ->
		# ZZZ should this be done via eval, rather than append to head?
		console.log "Compile #{@url} - *NO* eval box"
		@head.removeChild @element[0] if @findScript()
		@element = $ "<script>",
			type: "text/javascript"
			"data-url": @url
		# ZZZ enhance with try/catch for errors
		js = CoffeeEvaluator.compile @content
		@element.text js
		@head.appendChild @element[0]
	
	findScript: ->
		$("script[data-url='#{@url}']").length


class CoffeeCompilerEval
	
	lf: "\n"
	
	constructor: (@url) ->
		@evaluator = new CoffeeEvaluator
	
	compile: (@content) ->
		# Eval node exists
		console.log "Compile #{@url} for eval box"
		recompile = true
		@resultArray = @evaluator.process @content, recompile
		@result = @evaluator.stringify @resultArray
		@resultStr = @result.join(@lf) + @plotLines()  # ZZZ should stringify produce this directly?
		
	plotLines: ->
		l = @evaluator.numPlotLines @resultArray
		return "" unless l>0
		lfs = ""
		lfs += @lf for i in [1..l]
		lfs
		
	findStr: (str) -> @evaluator.findStr @resultArray, str 


class CoffeeEvaluator
	
	# Works:
	# switch, class
	# block comments set $blab.evaluator, but not processed because comment.
	
	# What's not supported:
	# unindented block string literals
	# unindented objects literals not assigned to variable (sees fields as different objects but perhaps this is correct?)
	# Destructuring assignments may not work for objects
	# ZZZ Any other closing chars (like parens) to exclude?
	
	noEvalStrings: [")", "]", "}", "\"\"\"", "else", "try", "catch", "finally", "alert", "console.log"]  # ZZZ better name?
	lf: "\n"
	
	# Class properties.
	@compile = (code, bare=false) ->
		CoffeeEvaluator.blabCoffee ?= new BlabCoffee
		js = CoffeeEvaluator.blabCoffee.compile code, bare
	
	@eval = (code, js=null) ->
		# Pass js if don't want to recompile
		js = CoffeeEvaluator.compile code unless js
		eval js
		js
	
	constructor: ->
		@js = null
	
	process: (code, recompile=true) -> #, stringify=true) ->
		stringify = true #ZZZ test
		compile = recompile or not(@evalLines and @js)
		if compile
			codeLines = code.split @lf
			# $blab.evaluator needs to be global so that CoffeeScript.eval can access it.
			$blab.evaluator = ((if @isComment(l) and stringify then l else "") for l in codeLines)
			@evalLines = ((if @noEval(l) then "" else "$blab.evaluator[#{n}] = ")+l for l, n in codeLines).join(@lf)
			js = null
		else
			js = @js
			
		try
			@js = CoffeeEvaluator.eval @evalLines, js  # Evaluated lines will be assigned to $blab.evaluator.
		catch error
			console.log "eval error", error
			
		return $blab.evaluator #unless stringify  # ZZZ perhaps break into 2 steps (separate calls): process then stringify?
		
	stringify: (resultArray) ->
		result = ((if e is "" then "" else (if e and e.length and e[0] is "#" then e else @objEval(e))) for e in resultArray)
		
	numPlotLines: (resultArray) ->
		# ZZZ generalize?
		n = null
		numLines = resultArray.length
		for b, idx in resultArray
			n = idx if (typeof b is "string") and b.indexOf("eval_plot") isnt -1
		d = if n then (n - numLines + 8) else 0
		if d and d>0 then d else 0
		
	findStr: (resultArray, str) ->
		p = null
		for e, idx in resultArray
			p = idx if (typeof e is "string") and e is str
		p
		
	noEval: (l) ->
		# ZZZ check tabs?
		return true if (l is null) or (l is "") or (l.length is 0) or (l[0] is " ") or (l[0] is "#") or (l.indexOf("#;") isnt -1)
		# ZZZ don't need trim for comment?
		for r in @noEvalStrings
			return true if l.indexOf(r) is 0
		false
	
	isComment: (l) ->
		return l.length and l[0] is "#" and (l.length<3 or l[0..2] isnt "###")
	
	objEval: (e) ->
		try
			line = $inspect2(e, {depth: 2})
			line = line.replace(/(\r\n|\n|\r)/gm,"")
			return line
		catch error
			return ""

window.CoffeeEvaluator = CoffeeEvaluator

#--- GitHub/Gist ---#

class GitHub
	
	ghApi: "https://api.github.com/repos/puzlet"  # Currently works only for puzlet.org (or localhost for testing).
	ghMembersApi: "https://api.github.com/orgs/puzlet/members"
	api: "https://api.github.com/gists"
	
	constructor: (@resources) ->
		@hostname = window.location.hostname
		@blabId = window.location.pathname.split("/")[1]  # ZZZ better way?
		@gistId = @getId()
		@setCredentials()  # None initially
		$(document).on "saveGitHub", =>
			@resources.updateFromContainers()
			@save()
			
	repoApiUrl: (path) ->
		"#{@ghApi}/#{@blabId}/contents/#{path}"
	
	loadResourceFromRepo: (resource, callback) ->
		# ZZZ Can resources be loaded earlier?
		path = resource.url
		url = @repoApiUrl path
		$.get(url, (data) =>
			console.log "Loaded resource #{path} from repo", data
			callback?(data)
		)
	
	loadGist: (callback) ->
		unless @gistId
			@data = null
			callback?()
			return
		url = "#{@api}/#{@gistId}"
		$.get(url, (@data) =>
			console.log "Gist loaded", @data
			@resources.setGistResources @data.files
			callback?()
		)
	
	save: (callback) ->
		unless @credentialsForm
			spec =
				blabId: @blabId
				setCredentials: (username, key) => @setCredentials username, key
				isRepoMember: (cb) => @isRepoMember cb
				updateRepo: (callback) => @commitChangedResourcesToRepo(callback)
				saveAsGist: (callback) => @saveAsGist(callback)
			@credentialsForm = new CredentialsForm spec
		@credentialsForm.open()
	
	saveAsGist: (callback) ->
		
		console.log "Save as Gist (#{if @auth then @username else 'anonymous'})"
		
		resources = @resources.select (resource) ->
			resource.spec.location is "blab"
		@files = {}
		@files[resource.url] = {content: resource.content} for resource in resources
		
		saved = =>
			resource.edited = false for resource in @resources
			callback?()
			$.event.trigger "codeSaved"
		
		if @gistId and @username
			if @data.owner?.login is @username
				@patch @ajaxData(), saved
			else
				console.log "Fork..."
				@fork((data) => 
					@gistId = data.id 
					@patch @ajaxData(), (=> @redirect())
				)
		else
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
				@gistId = data.id
				if @username
					@setDescription(=> @redirect())
				else
					@redirect()
			dataType: "json"
		
	patch: (ajaxData, callback) ->
		$.ajax
			type: "PATCH"
			url: "#{@api}/#{@gistId}"
			data: ajaxData
			beforeSend: (xhr) => @authBeforeSend(xhr)
			success: (data) ->
				console.log "Updated Gist", data
				callback?()
			dataType: "json"
		
	fork: (callback) ->
		$.ajax
			type: "POST"
			url: "#{@api}/#{@gistId}/forks"
			beforeSend: (xhr) => @authBeforeSend(xhr)
			success: (data) =>
				console.log "Forked Gist", data
				callback?(data)
			dataType: "json"
	
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


	setDescription: (callback) ->
		ajaxData = JSON.stringify(description: @description())
		@patch ajaxData, callback
		
	description: ->
		description = document.title
		description += " [http://puzlet.org?gist=#{@gistId}]" if @gistId
	
	redirect: ->
		blabUrl = "/?gist=#{@gistId}"
		window.location = blabUrl
		
	getId: ->
		query = location.search.slice(1)
		return null unless query
		h = query.split "&"
		p = h?[0].split "="
		gist = if p.length and p[0] is "gist" then p[1] else null
	
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
	
	setCredentials: (@username, @key) ->
		make_base_auth = (user, password) ->
			tok = user + ':' + password
			hash = btoa(tok)
			"Basic " + hash
		
		if @username and @key
			@auth = make_base_auth @username, @key
			@authBeforeSend = (xhr) => xhr.setRequestHeader('Authorization', @auth)
		else
			@authBeforeSend = (xhr) =>


class CredentialsForm
	
	constructor: (@spec) ->
		
		@blabId = @spec.blabId
		
		@username = $.cookie("gh_user")
		@key = $.cookie("gh_key")
		
		@dialog = $ "<div>"
			id: "github_save_dialog"
			title: "Save to GitHub"
		
		@dialog.dialog
			autoOpen: false
			height: 500
			width: 500
			modal: true
			close: => @form[0].reset()
		
		@spec.setCredentials @username, @key
		@setButtons()
		
		@form = $ "<form>"
			id: "github_save_form"
			submit: (evt) => evt.preventDefault()
				
		@dialog.append @form
		
		@usernameField()
		@keyField()
		@infoText()
		@saving = $ "<p>"
			text: "Saving..."
			css:
				fontSize: "16pt"
				color: "green"
		@dialog.append @saving
		@saving.hide()
		
	open: ->
		@usernameInput.val @username
		@keyInput.val @key
		@setButtons()
		@dialog.dialog "open"
		
	usernameField: ->
		id = "username"
		label = $ "<label>"
			"for": id
			text: "Username"
			
		@usernameInput = $ "<input>"
			name: "username"
			id: id
			value: @username
			class: "text ui-widget-content ui-corner-all"
			change: => @setCredentials()
			
		@form.append(label).append(@usernameInput)
		
	keyField: ->
		id = "key"
		label = $ "<label>"
			"for": id
			text: "Personal access token"
		
		@keyInput = $ "<input>"
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
		@div = $ "<div>"
			id: "save_button_container"
			css:
				position: "fixed"
				top: 10
				right: 10
		
		@b = $ "<button>"
			click: =>
				@b.hide()
				#@saving()
				@callback?()
			title: "When you're done editing, save your changes to GitHub."
		@b.button label: "Save"
		
		# ZZZ no longer used
		@savingMessage = $ "<span>"
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
		#$(document).on "codeSaved", => @savingMessaage.hide()
		
	saving: ->
		@b.hide()
		@savingMessage.show()

