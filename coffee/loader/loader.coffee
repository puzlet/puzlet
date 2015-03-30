###
TODO: use full file path instead of subf - is subf by itself ever really needed?
TODO: see if we can do without blabLocation, if we have org/repo name in resources.json.
###


###
TODO: if localhost, try loading resource locally first.  if fails, from github.
support {css: "..."} in resources.coffee
loadJSON broken - Resource.load no longer supports type?

TODO: have local env file so we know whether to try loading locally (localhost or deployed host)?
TODO: for deployed host, may also need to know root folder?
###

console.log "LOADER"

class Loader
    
    #--- Example resources.coffee ---
    # Note that order is important for html rendering order, css cascade order, and script execution order.
    # But blab resources can go at top because always loaded after external resources.
    ###
    # TODO:
    [
        "main.html",
        "style.css",
        "bar.js",
        "foo.coffee",
        "main.coffee",
        "/some-repo/snippet.html",
        "/other-repo/foo.css",
        "/puzlet/js/d3.min.js",
        "http://domain.com/script.js",
        "/ode-fixed/ode.coffee"
    ]
    ###
        
    # TODO: load jquery ui if balb basic?
    htmlResources: if window.blabBasic then [{url: ""}] else [
        {url: "/puzlet/puzlet/css/coffeelab.css"}
        {url: "//ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/themes/smoothness/jquery-ui.css", var: "jQuery"}  # Alternative
    ]
    
    # TODO: most of these will become part of puzlet math package.  jquery ui loaded by user?
    scriptResources: [
        {url: "/puzlet/puzlet/js/acorn.js"}
        {url: "/puzlet/puzlet/js/numeric-1.2.6.js"}
        {url: "/puzlet/puzlet/js/jquery.flot.min.js"}
        {url: "/puzlet/puzlet/js/compile.js"}
        {url: "/puzlet/puzlet/js/jquery.cookie.js"}
        {url: "//ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/jquery-ui.min.js", var: "jQuery.ui"}   # Alternative
    ]
    
    constructor: (@render, @done) ->
        @resources = $blab.resources
        @resources.init
            preload: (callback) => @loadCssAndScripts(callback)
            postload: (callback) => @done()
    
    # Initiate GitHub object and load Gist files - these override blab files.
    TO_ADD_loadGitHub: (callback) ->
        @github = new GitHub @resources
        @github.loadGist callback
    
    # Prepend /puzlet/css/puzlet.css to list; prepend script resources (CoffeeScript compiler; math).
    # TODO: Some of these will wind up in resources.coffee.
    loadCssAndScripts: (callback) ->
        @resources.add @htmlResources
        @resources.add @scriptResources
        @resources.loadUnloaded => callback?()
    
    loadAce: (callback) ->
        load = (resources, callback) =>
            @resources.add resources
            @resources.load ["js", "css"], => callback?()
        new Ace.Resources load, =>
            @resources.render()  # Render Ace editors
            @resources.compileCoffee (coffee) -> coffee.hasEval()  # Compile any CoffeeScript that has associated eval box.
            callback?()

###
*******SPECIFICATION*******
        
===Supported URLs for current blab location===
http://localhost:port/owner/repo (note: repo could be owner.github.io)
http://puzlet.org
http://puzlet.org/repo
http://owner.github.io
http://owner.github.io/repo
(We could also support subfolders)
TODO: should work on any domain (http://domain.com/path/to/owner[/repo]), if blabs deployed there.

From these, we derive:
owner, repo names of current page (index.html).

===For resources.coffee, support these URLs===

File extension affects whether resource is linked or inlined.
JS/CSS files are linked (not inlined), unless they come from current blab (then they are inlined).
All other file types are loaded via Ajax (if possible), and inlined.  Use GitHub API if foreign.  IE issue here.
TODO: Also need {css/js: generalUrl}.

---General URLs---
Must begin with http:// or //
(No special interpretation of owner/repo.)

http://general.com/path/to/file.ext (general URL)
http://puzlet.org/repo/path/to/file.ext
http://owner.github.io/repo/path/to/file.ext
http://rawgit ...

GitHub API link.  This needs to be used for foreign github JS/CSS resources
that can't be accessed via github.io.
This does not work with IE, and so it may be better to copy such resource to location in same org,
so it is accessible locally or via github.io.
http://api.github.com/...

---Special resource identifiers---
Load locally if localhost (TODO: or deployment domain) and file available; otherwise get from github.

/owner/repo/path/to/file.ext 
path/to/file.ext (use current page's host owner/repo)

###

#-----------------Blab and Resource Locations---------------------------------#

class URL
    
    constructor: (@url) ->
        @a = document.createElement "a"
        @a.href = @url
        
        # URL components
        @hostname = @a.hostname
        @pathname = @a.pathname
        @search = @a.search 
        
        @host = @hostname.split "."
        @path = if @pathname then @pathname.split("/")[1..] else []
        
        @hasPath = @path.length>0
        
        match = if @hasPath then @pathname.match /\.[0-9a-z]+$/i else null
        @fileExt = if match?.length then match[0].slice(1) else null
        
        @file = if @fileExt then @path[-1..][0] else null
        
    onWeb: ->
        w = (url) => @url.indexOf(url) is 0
        w("http://") or w("https://") or w("//")
        
    filePath: ->
        # TODO: call "relFilePath" ?
        base = new URL "."
        @pathname.replace(base.pathname, "")
        
    subfolder: (filePathIdx) ->
        endIdx = if @file then -2 else -1
        s = @path[(filePathIdx)..endIdx].join("/")
        if s then "/"+s else ""


class OLD___BlabLocation extends URL  # TODO: call this PageLocation?
    
    constructor: (@url=window.location.href) ->
        
        super @url
        
        # http://localhost:port/owner/repo (note: no support for http://localhost:port/owner - instead http://localhost:port/owner/homepage)
        if @hostname is "localhost"
            @owner = @path[0]
            @repoIdx = 1
            
        # http://domain.com/path/to/owner/repo | http://domain.com/path/to/owner
        # TODO: need some kind of env variable (incl in .gitignore?) to configure where repoIdx is (and ownerIdx) in path.
        # TODO ...
        
        # http://puzlet.org/repo | http://puzlet.org
        if @hostname is "puzlet.org"
            @owner = "puzlet"
            @repoIdx = 0
        
        # http://owner.github.io/repo | http://owner.github.io
        if GitHub.isIoUrl(@url)
            @owner = @host[0]
            @repoIdx = 0
            
        return unless @owner  # Not a blab resource if no owner
        
        if @hasPath
            @repo = @path[@repoIdx]
            @subf = @subfolder(@repoIdx + 1)
        else
            @repo = null
            @subf = null
        
        @gitHub = new GitHub {@owner, @repo}
        @source = @gitHub.sourcePageUrl() #"https://github.com/#{@owner}/#{@repo ? ''}" if @owner
        


class ResourceLocation extends URL
    # Abstract class
        
    # TODO: handle load error
    
    owner: null
    repo: null
    #subf: null
    filepath: null
    inBlab: false
    source: null
    gitHub: null
    
    constructor: (@url) ->
        super @url
        # TODO: @filepath?
        #@subf = @subfolder(0)
        @source = @url
        @loadUrl = @url
        
    load: (callback) ->
        # Ajax-load method.  TODO: continue if load error.
        url = @url+"?t=#{Date.now()}"
        console.log "LOAD #{url}"
        $.get(url, ((data) -> callback(data)), "text")

class WebResourceLocation extends ResourceLocation
    
    loadType: "ext"
    cache: true


# TODO: Should this be called GitHubResourceLocation?
class BlabResourceLocation extends ResourceLocation
    
    loadType: null  # Defined in constructor
    cache: null  # Defined in constructor
    
    constructor: (@url) ->
        super @url
        
        @blabOwner = $blab.gitHub.owner
        @blabRepo = $blab.gitHub.repo
        
        if @fullPath()
            # /owner/repo/path/to/file.ext
            @owner = @path[0]
            @repo = @path[1]
            @filepath = @path[2..].join("/")
            @inBlab = @owner is @blabOwner and @repo is @blabRepo
        else
            # path/to/file.ext
            @owner = @blabOwner
            @repo = @blabRepo
            @filepath = @filePath()
            @inBlab = true  # TODO: what if ../relative/path ?
        
        @localOrgPath = $blab.gitHub?.localConfig?.orgs?[@owner]
        path = @filepath
        @gitHub = new GitHub {@owner, @repo, path}
        
        if @inBlab
            @loadUrl = @filepath
        else
            @loadUrl = if @localOrgPath then "#{@localOrgPath}/#{@repo}/#{@filepath}" else @gitHub.linkedUrl()
        
        # loadType is used only to JS/CSS resources.
        # if loadType="ext" and is on GitHub then resource must be accessible via github.io.
        @loadType = if @inBlab then "blab" else "ext"
        @cache = not @inBlab and @owner is "puzlet"  # TODO: better way?
        
        console.log @owner, @repo, @filepath, @loadUrl
        
        console.log @gitHub.linkedUrl()
        @source = @gitHub.sourcePageUrl()
    
    load: (callback) ->
        # ZZZ what if not coffee?  JS/CSS handled elsewhere?
        console.log "*** Blab load #{@url} => #{@loadUrl}"
        url = @loadUrl + "?t=#{Date.now()}"  # No cache
        # Ajax-load method.  TODO: continue if load error.
        $.get(url, ((data) -> callback(data)), "text")
    
    fullPath: -> @url?.indexOf("/") is 0


class GitHubApiResourceLocation extends ResourceLocation
    
    loadType: "api"
    cache: false
    
    constructor: (@url) ->
        
        super @url
        
        @api = new GitHubApi @url
        return unless @api.owner
        @owner = @api.owner
        @repo = @api.repo
        @path = @api.path
        @gitHub = new GitHub {@owner, @repo, @path}
        @source = @gitHub.sourcePageUrl()
        
    load: (callback) -> @api.load callback


# Factory function
resourceLocation = (url) ->
    
    resource = new URL url
    if GitHubApi.isApiUrl(resource.url)
        # http://api.github.com/repos/owner/repo/contents/path/to/file.ext
        # This is for foreign JS/CSS resources that don't have github.io repo and need to be linked.
        R = GitHubApiResourceLocation
    else if resource.onWeb()
        # http://... or //...
        R = WebResourceLocation
    else
        # /owner/repo/path/to/file.ext or # path/to/file.ext
        R = BlabResourceLocation
    return new R(url)
    


#-----------------------------------------------------------------------------#

# TODO: class for github io?
class GitHub
    
    branch: "gh-pages"  # Default
    
    @isIoUrl: (url) ->
        u = new URL url
        host = u.host
        host.length is 3 and host[1] is "github" and host[2] is "io" 
    
    constructor: (@spec) ->
        {@owner, @repo, @path} = @spec
    
    sourcePageUrl: ->
        return null unless @owner
        "https://github.com/#{@owner}/#{@repo}/blob/#{@branch}/#{@path}"
        
    linkedUrl: ->
        return null unless @owner
        "https://#{@owner}.github.io/#{@repo}/#{@path}"
        
    apiUrl: ->
        return null unless @owner
        GitHubApi.getUrl {@owner, @repo, @path}
    
    urls: ->
        sourcePageUrl: @sourcePageUrl()
        linkedUrl: @linkedUrl()
        apiUrl: @apiUrl()


class GitHubApi extends URL
    
    @hostname: "api.github.com"
    
    @isApiUrl: (url) ->
        u = new URL url
        path = u.path
        u.hostname is GitHubApi.hostname and path.length>=5 and path[0] is "repos" and path[3] is "contents"
        
    @getUrl: (spec) ->
        {owner, repo, path} = spec
        "https://#{GitHubApi.hostname}/repos/#{owner}/#{repo}/contents/#{path}"
    
    @loadParameters: (url) ->
        type: "json"
        process: (data) ->
            content = data.content.replace(/\s/g, '')  # Remove whitespace. Fixes parsing issue for Safari.
            atob(content)
       
    constructor: (@url) ->
        super @url
        return unless GitHubApi.isApiUrl(@url)
        @owner = @path[1]
        @repo = @path[2]
        # TODO: @filepath ?
        #@subf = @subfolder(4)
        
    load: (callback) ->
        success = (data) =>
            content = data.content.replace(/\s/g, '')  # Remove whitespace. Fixes parsing issue for Safari.
            callback(atob(content))
        $.get(@url, success, "json")


testBlabLocation = ->
    
    loc = (url) ->
        b = new BlabLocation url
        console.log b, b.gitHub?.urls()
    
    #    loc null
        #console.log "&&&&&&&&", l
    
    #    loc "http://puzlet.org/repo/path/to"
        #console.log "&&&&&&&&", l
    
    #    loc "http://owner.github.io/repo/path"
        #console.log "&&&&&&&&", l
    
    #    loc "http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js"
        #console.log "&&&&&&&&", l
        
    r = (url) ->
        z = resourceLocation url
        #        z = new XResourceLocation url
        console.log z, z.gitHub?.urls()
    
    r "http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js"
    #console.log "********", l
    
    r "http://puzlet.org/puzlet/coffee/main.coffee"
    #console.log "********", l
    
    r "/owner/repo/main.coffee"
    #console.log "********", l
    
    r "main.coffee"
    #console.log "********", l
    
    r "http://api.github.com/repos/owner/repo/contents/path/to/file.ext"
    #console.log "********", l
    
    
#
#testBlabLocation()


#-----------------------------------------------------------------------------#

class Resource
    
    constructor: (@spec) ->
        # ZZZ option to pass string for url
        @location = @spec.location ? resourceLocation @spec.url
        @url = @location.url
        @loadUrl = @location.loadUrl
        @fileExt = @spec.fileExt ? @location.fileExt
        @id = @spec.id
        @loaded = false
        @head = document.head
        @containers = new ResourceContainers this
    
    load: (callback) ->
        # Default file load method.
        # Uses jQuery.
        
        # Load Gist
        if @spec.gistSource
            @content = @spec.gistSource
            @postLoad callback
            return
        
        @location.load((@content) => @postLoad callback)
    
    postLoad: (callback) ->
        @loaded = true
        callback?()
    
    isType: (type) -> @fileExt is type
    
    setContent: (@content) ->
        @containers.setEditorContent @content  # ZZZ exclude editor that triggered change (2nd optional arg)
    
    setFromEditor: (editor) ->
        @content = editor.code()
        @containers.setFromEditor editor
    
    update: (@content) ->
        console.log "No update method for #{@url}"
    
    updateFromContainers: ->
        @containers.updateResource()
    
    hasEval: -> @containers.evals().length
    
    render: -> @containers.render()
    
    getEvalContainer: -> @containers.getEvalContainer()
    
    inBlab: -> @location.inBlab
    
    @typeFilter: (types) ->
        (resource) ->
            if typeof types is "string"
                resource.isType types
            else
                # Array of strings
                for type in types
                    return true if resource.isType type
                false


# Classes that override the Resource load method:
# CssResourceInline, JsResourceInline (creates HTML element before regular load)
# CssResourceLinked, JsResourceLinked (regular <link>/<script> load)
# CoffeeResource (compiler callback)

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
            type: @mime if @mime
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
        #@style.setAttribute "type", "text/css"
        @style.setAttribute "rel", "stylesheet"
        t = Date.now()
        @style.setAttribute "href", @loadUrl  #+"?t=#{t}"
#        @style.setAttribute "href", @url  #+"?t=#{t}"
        #@style.setAttribute "data-url", @url
        
        # Old browsers (e.g., old iOS) don't support onload for CSS.
        # And so we force postLoad even before CSS loaded.
        # Forcing postLoad generally ok for CSS because won't affect downstream dependencies (unlike JS). 
        setTimeout (=> @postLoad callback), 0
        #@style.onload = => @postLoad callback
        
        @head.appendChild @style


class JsResourceInline extends ResourceInline
    
    tag: "script"
    #mime: "text/javascript"


class JsResourceLinked extends Resource
    
    load: (callback) ->
        @script = document.createElement "script"
        #@script.setAttribute "type", "text/javascript"
        @head.appendChild @script
        @script.onload = => @postLoad callback
        #@script.onerror = => console.log "Load error: #{@url}"
        
        src = @loadUrl  # TODO: if this fails, try loading from github
#        src = @url  # TODO: if this fails, try loading from github
        console.log "JsResourceLinked load", src
        t = if @location.cache then "" else "?t=#{Date.now()}"
        @script.setAttribute "src", src+t


class CoffeeResource extends Resource
    
    load: (callback) -> 
        super =>
            # Map url to valid DOM id: /owner/repo/path/to/file.ext -> owner:repo:path:to:file.ext
            # No longer used.
            #@id = @url.replace(/^\//g, "")
            #@id = @id.replace(/\//g, ":")
            spec = {id: @url, preProcess: @spec.orig?.preProcess}
            @compiler = if @hasEval() or @spec.orig.doEval then $coffee.evaluator(spec) else $coffee.compiler(spec)
            @compiled = false
            callback?()
            
    compile: ->
        $blab.evaluatingResource = this
        @compiler.compile @content
        @compiled = true
        @resultArray = @compiler.resultArray
        @resultStr = @compiler.result
        $.event.trigger("compiledCoffeeScript", {url: @url})
    
    update: (@content) -> @compile()


class JsonResource extends Resource


class ResourceFactory
    
    # The resource type if based on:
    #   * file extension (html, css, js, coffee, json, py, m)
    #   * url path (in blab or external or github api).
    # Ajax-loaded resources:
    #   * Any resource in current blab.
    #   * html, coffee, json, py, m resources.
    # For ajax-loaded resources, source is available for in-browser editing.
    # All other resources are "linked" resources - loaded via <link href=...> or <script src=...>.
    # load method specifies resources to load (via filter):
    #   * linked resources are appended to DOM as soon as they are loaded.
    #   * ajax-loaded resources (js, css) are appended after all resources loaded (for call to load).
    resourceTypes:
        html: {all: HtmlResource}
        css: {blab: CssResourceInline, ext: CssResourceLinked, api: CssResourceInline}
        js: {blab: JsResourceInline, ext: JsResourceLinked, api: JsResourceInline}
        coffee: {all: CoffeeResource}
        json: {all: JsonResource}
        py: {all: Resource}
        m: {all: Resource}
        svg: {all: Resource}
        txt: {all: Resource}
    
    constructor: (@getGistSource) ->
    
    create: (spec) ->
        
        console.log "===== LOAD", spec.url
        
        return null if @checkExists spec
        
        if spec.url
            url = spec.url
        else
            {url, fileExt} = @extractUrl spec
        
        location = resourceLocation url
        
        fileExt ?= location.fileExt
        
        spec =
            id: spec.id
            location: location
            fileExt: fileExt
            gistSource: @getGistSource(url)
            orig: spec  # TODO: hack
        
        subTypes = @resourceTypes[fileExt]
        return null unless subTypes
        
        subtype = if subTypes.all? then "all" else location.loadType
        resource = new subTypes[subtype](spec)
        
    checkExists: (spec) ->
        v = spec.var
        return false unless v
        vars = v?.split "."
        z = window
        for x in vars
            z = z[x]
            return false unless z
        console.log "Not loading #{v} - already exists"
        true
    
    extractUrl: (spec) ->
        for p, v of spec
            # Currently handles only one property.
            url = v
            fileExt = p
        {url, fileExt}


#-----------------------------------------------------------------------------#

class ResourceContainers
    
    # <div> attribute names for source and eval nodes. 
    fileContainerAttr: "data-file"
    evalContainerAttr: "data-eval"
    
    constructor: (@resource) ->
        @url = @resource.url
    
    render: ->
        @fileNodes = (new Ace.EditorNode $(node), @resource for node in @files())
        @evalNodes = (new Ace.EvalNode $(node), @resource, @fileNodes[idx] for node, idx in @evals())
        $pz.codeNode ?= {}
        $pz.codeNode[file.editor.id] = file.editor for file in @files
        
    getEvalContainer: ->
        # Get eval container if there is one (and only one).
        return null unless @evalNodes?.length is 1
        @evalNodes[0].container
        
    setEditorContent: (content) ->
        triggerChange = false
        node.setCode(triggerChange) for node in @fileNodes
        
    setFromEditor: (editor) ->
        triggerChange = false
        for node in @fileNodes
            node.setCode(triggerChange) unless node.editor.id is editor.id
        
    updateResource: ->
        return unless @fileNodes.length
        console.log "Multiple editor nodes for resource.  Updating resource from only first editor node.", @resource if @fileNodes.length>1
        @resource.update(@fileNodes[0].code())
        #console.log "Potential update issue because more than one editor for a resource", @resource if @fileNodes.length>1
        #for fileNode in @fileNodes
        #   @resource.update(fileNode.code())
    
    files: -> $("div[#{@fileContainerAttr}='#{@url}']")
    
    evals: -> $("div[#{@evalContainerAttr}='#{@url}']")


# TODO: Not used?
class EditorContainer
    
    constructor: (@resource, @div) ->
        @node = new Ace.EditorNode @div, @resource
        
    updateResource: ->
        # ZZZ need event/listeners here for other related containers.
        @resource.update(@node.code())


# TODO: Not used?
class EvalContainer
    
    constructor: (@resource, @div) ->
        @node = new Ace.EvalNode @div, @resource
        
    getContainer: ->
        @node.container
    


#-----------------------------------------------------------------------------#

class Resources
    
    # jQuery and puzlet.json (if local/deployment) are loaded in Puzlet bootstrap script (//puzlet.org/puzlet.js).
    coreResources: [
        {url: "/puzlet/coffeescript/coffeescript.js"}
        {url: "/puzlet/coffeescript/compiler.js"}
        {url: "/puzlet/puzlet/js/wiky.js", var: "Wiky"}  # TODO: does this need to be here?
        {url: "/puzlet/puzlet/js/google_analytics.js"}  # TODO: does this need to be here?
    ]
    
    #OLD gitHubFile: "../github.json"
    
    resourcesSpec: "resources.coffee"
    
    constructor: (spec) ->
        @resources = []
        @factory = new ResourceFactory (url) => @getGistSource url
        @changed = false
        
    # Load coffeescript compiler and other core resources.
    # Supports preload and postload callbacks (before/after resources.coffee loaded).
    init: (spec) ->
        
        core = (cb) => @addAndLoad @coreResources, cb
        
        preload = spec.preload ? (f) -> f()
        postload = spec.postload ? (f) -> (f)
        
        resources = (cb) =>
            @loadFromSpecFile
                url: @resourcesSpec
                callback: => cb()
                #    @loadHtmlCss => @loadScripts => cb()
        
        core -> preload -> resources -> postload()
    
    addAndLoad: (resourceSpecs, callback) ->
        resources = @add resourceSpecs
        @loadUnloaded callback
        resources
    
    add: (resourceSpecs) ->
        resourceSpecs = [resourceSpecs] unless resourceSpecs.length
        newResources = []
        for spec in resourceSpecs
            resource = @factory.create spec
            continue unless resource
            newResources.push resource
            @resources.push resource
        if newResources.length is 1 then newResources[0] else newResources
    
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
        
    # Load from resources.coffee specification.
    # Get ordered list of resources (html, css, js, coffee).
    loadFromSpecFile: (spec) ->
        url = spec.url
        specFile = @add(url: url, preProcess: @specFilePreProcessCode(url))
        @load ((resource) -> resource.url is url), =>
            specFile.compile()  # TODO: check valid coffee?
            @loadHtmlCss => @loadScripts => spec.callback?()
    
    # Process specification in resources.coffee.
    processSpec: (resources) ->
        console.log "----Process files in resources.coffee"
        #inBlab = specUrl.indexOf("/") is -1  # Current blab's resources.coffee
        #@currentBlab = resources.github if inBlab
        for url in resources.load
            @add {url} if typeof url is "string" and url.length
        #@loadHtmlCss => @loadScripts => #spec.callback?()
    
    # Defines helper function "resources" for preamble JS of resources.coffee. 
    specFilePreProcessCode: (url) ->
        (code) -> "resources = (obj) -> $blab.resources.processSpec obj\n\n"+code
        
    # Load html and css:
    #   * all html via ajax.
    #   * external css via <link>; auto-appended to dom as soon as resource loaded.
    #   * blab css via ajax; auto-appended to dom (inline) after *all* html/css loaded.
    # After all html/css loaded, render html via Wiky.
    # html and blab css available as source to be edited in browser.
    loadHtmlCss: (callback) ->
        @load ["html", "css"], =>
            # TODO: add render
            #@render html.content for html in @resources.select("html")  # TODO: callback for HTMLResource?
            callback?()
            
    # Async load js and coffee; and py/m:
    #   * external js via <script>; auto-appended to dom, and run.
    #   * blab js and all coffee via ajax; auto-appended to dom (inline) after *all* js/coffee loaded.
    #   * py/m via ajax; no action loading.
    # After all scripts loaded: 
    #   * compile each coffee file, with post-js processing if not #!vanilla.
    #   * append JS (blab js or compiled coffee) to dom: external js (from coffee) first, then current blab js.
    # coffee and blab js available as source to be edited in browser.
    # (Loading scripts after HTML/CSS improves html rendering speed.)
    # Note: for large JS file (even 3rd party), put in repo without gh-pages (web page).
    loadScripts: (callback) ->
        @load ["json", "js", "coffee", "py", "m", "svg", "txt"], =>
            # Before Ace loaded, compile any CoffeeScript that has no associated eval box.
            @compileCoffee (coffee) -> not(coffee.hasEval() or coffee.spec.orig.doEval or coffee.compiled)
            callback?()
            
    # TODO: duplicate code?
    compileCoffee: (coffeeFilter) ->
        # ZZZ do external first; then blabs.
        filter = (resource) -> resource.isType("coffee") and coffeeFilter(resource)
        coffee.compile() for coffee in @select filter
    
    appendToHead: (filter) ->
        filter = @filterFunction filter
        resources = @select((resource) -> not resource.inDom?() and resource.appendToHead? and filter(resource))
        resource.appendToHead() for resource in resources
        
    select: (filter) ->
        filter = @filterFunction filter
        (resource for resource in @resources when filter(resource))
        
    filterFunction: (filter) ->
        if typeof filter is "function" then filter else Resource.typeFilter(filter)
        
    find: (id) ->
        # id can be resource id or resource url.  Tries to match resource id first.
        f = (p) =>
            return r for r in @resources when r[p] is id
            null
        resource = f "id"
        return resource if resource
        resource = f "url"
        
    getContent: (id) ->
        # id can be resource id or resource url.  Tries to match resource id first.
        resource = @find(id)
        if resource
            content = resource.content
            if resource.fileExt is "json" then JSON.parse(content) else content
        else
            null
    
    getJSON: (id) ->
        content = @getContent id
        JSON.parse(content) if content
    
    loadJSON: (url, callback) ->
        resource = @find url
        resource ?= @add {url: url}
        return null unless resource
        resource.load (-> callback?(resource.content)), "json"
    
    render: ->
        resource.render() for resource in @resources
    
    setGistResources: (@gistFiles) ->
    
    getGistSource: (url) ->
        @gistFiles?[url]?.content ? null
    
    updateFromContainers: ->
        for resource in @resources
            resource.updateFromContainers() if resource.edited


#-----------------------------------------------------------------------------#

resources = new Resources
    #gitHub: $blab.gitHub  # From Puzlet bootstrap
    # TODO: gist source

# Public interface.  $blab is defined in Puzlet bootstrap script (//puzlet.org/puzlet.js)
console.log "$blab", $blab

$blab.resources = resources
$blab.loadJSON = (url, callback) => resources.loadJSON(url, callback)
$blab.resource = (id) => resources.getContent id

render = ->
ready = ->
new Loader(render, ready)

#-----------------------------------------------------------------------------------------------------------

class OLD_Blab
    
    constructor: ->
        @publicInterface()
        @location = new ResourceLocation  # For current page
        #window.blabBasic = window.blabBasic? and window.blabBasic
        #@page = if window.blabBasic then (new BasicPage(@location)) else (new Page(@location))
        #render = (wikyHtml) => @page.render wikyHtml
        #ready = => @page.ready @loader.resources
        render = ->
        ready = ->
        @loader = new Loader @location, render, ready
        #$pz.renderHtml = => @page.rerender()
        
    publicInterface: ->
        window.$pz = {}
        window.$blab = {}  # Exported interface.
        window.console = {} unless window.console?
        window.console.log = (->) unless window.console.log?
        #$pz.AceIdentifiers = Ace.Identifiers
        $blab.codeDecoration = true
        


class OLD_ResourceLocation
    
    # This does not use jQuery. It can be used for before JQuery loaded.
    
    # ZZZ Handle github api path here.
    # ZZZ Later, how to support custom domain for github io?
    
    ###
    Locations:
    localhost:8000/owner/repo/path
    puzlet.org/repo/path
    owner.github.io/repo/path
    /owner/repo/path
    path
    ...?gist=...
    ###
    
    constructor: (@url=window.location.href) ->
        
        @a = document.createElement "a"
        @a.href = @url
        
        # URL components
        @hostname = @a.hostname
        @path = @a.pathname
        @search = @a.search 
        @getGistId()
        
        # Decompose into parts
        hostParts = @hostname.split "."
        @pathParts = if @path then @path.split "/" else []
        hasPath = @pathParts.length
        specOwner = hasPath and @url.indexOf("/") isnt -1 #@pathParts[0] is ""
        
        # Resource host type
        @isLocalHost = @hostname is "localhost"
        @isPuzlet = @hostname is "puzlet.org"  # TODO: needed?
        @isGitHub = hostParts.length is 3 and hostParts[1] is "github" and hostParts[2] is "io"  # TODO: needed?
        # Example: https://api.github.com/repos/OWNER/REPO/contents/FILE.EXT
        @isGitHubApi = @hostname is "api.github.com" and @pathParts.length is 6 and @pathParts[1] is "repos" and @pathParts[4] is "contents"
            
        # Owner/organization
        @owner = switch
            when @isLocalHost and specOwner then @pathParts[1]
            when @isPuzlet then "puzlet"
            when @isGitHub
                if specOwner
                    @pathParts[1]
                else
                    hostParts[0]
            when @isGitHubApi and hasPath then @pathParts[2]
            else null
        
        # Repo and subfolder path
        @repo = null
        @subf = null
        if hasPath
            repoIdx = switch
                when @isLocalHost
                    if specOwner then 2 else 1
                    #then 2
                when @isPuzlet then 1
                when @isGitHub
                    if specOwner then 2 else 1
                    #then 1
                when @isGitHubApi then 3
                else null
            @repoIdx = repoIdx  # TODO: temp
            if repoIdx
                @repo = @pathParts[repoIdx]
                pathIdx = repoIdx + (if @isGitHubApi then 2 else 1)
                @subf = @pathParts[pathIdx..-2].join "/"
        
        # File and file extension
        match = if hasPath then @path.match /\.[0-9a-z]+$/i else null  # ZZZ dup code - more robust way?
        @fileExt = if match?.length then match[0].slice(1) else null
        @file =
            if @fileExt
                if specOwner
                    @pathParts[-1..][0]  # TODO: debug
                else
                    @pathParts[-1..][0]
            else
                null
        @inBlab = @file and @url.indexOf("/") is -1  # TODO: redundant?   !!! used in resource factory
        
        if @gistId
            # Gist
            f = @file?.split "."
            @source = "https://gist.github.com/#{@gistId}" + (if @file then "#file-#{f[0]}-#{f[1]}" else "")
        else if @owner and @repo
            # GitHub repo (or puzlet.org).
            s = if @subf then "/#{@subf}" else ""  # Subfolder path string
            branch = "gh-pages"  # ZZZ bug: need to get branch - could be master or something else besides gh-pages.
            @source = "https://github.com/#{@owner}/#{@repo}#{s}" + (if @file then "/blob/#{branch}/#{@file}" else "")
            @apiUrl = "https://api.github.com/repos/#{@owner}/#{@repo}/contents#{s}" + (if @file then "/#{@file}" else "")
            @linkedUrl = "https://#{@owner}.github.io/#{@repo}#{s}/#{@file}"
        else
            # Regular URL - assume source at same location.
            @source = @url
            
        # https://api.github.com/repos/puzlet-demo/resources.coffee/contents/resources.coffee
        # https://api.github.com/repos/stemblab/puzlet-demo/contents/resources.coffee
        
        console.log this
        
    getGistId: ->
        # ZZZ dup code - should really extend to get general URL params.
        @query = @search.slice(1)
        return null unless @query
        h = @query.split "&"
        p = h?[0].split "="
        @gistId = if p.length and p[0] is "gist" then p[1] else null
        


class OLD_Loader
    
    #--- Example resources.json ---
    # Note that order is important for html rendering order, css cascade order, and script execution order.
    # But blab resources can go at top because always loaded after external resources.
    ###
    [
        "main.html",
        "style.css",
        "bar.js",
        "foo.coffee",
        "main.coffee",
        "/some-repo/snippet.html",
        "/other-repo/foo.css",
        "/puzlet/js/d3.min.js",
        "http://domain.com/script.js",
        "/ode-fixed/ode.coffee"
    ]
    ###
    
    # Now in Resources class
    OLD_coreResources1: [
        #       {url: "http://code.jquery.com/jquery-1.8.3.min.js", var: "jQuery"}
        {url: "http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js", var: "jQuery"}  # Alternative
     #   {url: "/puzlet/puzlet/js/google_analytics.js"}
        #       {url: "http://code.jquery.com/ui/1.9.2/themes/smoothness/jquery-ui.css", var: "jQuery"}
     #   {url: "http://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/themes/smoothness/jquery-ui.css", var: "jQuery"}  # Alternative
     #   {url: "/puzlet/puzlet/js/coffeescript.js"}  # TODO: get from coffeescript repo
     #   {url: "/puzlet/coffeescript/compiler.js"}
        # {url: "http://localhost:8000/puzlet/coffeescript/compiler.js"}  # TODO: FIX!!!
     #   {url: "/puzlet/puzlet/js/wiky.js", var: "Wiky"}
    ]
    
    # Now in Resources class
    OLD_coreResources2: [
        #       {url: "http://code.jquery.com/jquery-1.8.3.min.js", var: "jQuery"}
        # {url: "http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js", var: "jQuery"}  # Alternative
        {url: "/puzlet/puzlet/js/google_analytics.js"}
        #       {url: "http://code.jquery.com/ui/1.9.2/themes/smoothness/jquery-ui.css", var: "jQuery"}
        # {url: "http://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/themes/smoothness/jquery-ui.css", var: "jQuery"}  # Alternative
        {url: "/puzlet/coffeescript/coffeescript.js"}
        {url: "/puzlet/coffeescript/compiler.js"}
        # {url: "http://localhost:8000/puzlet/coffeescript/compiler.js"}  # TODO: FIX!!!
        {url: "/puzlet/puzlet/js/wiky.js", var: "Wiky"}
    ]
    
    resourcesList: {url: "resources.json"}
    resourcesList2: {url: "resources.coffee"}
    
    htmlResources: if window.blabBasic then [{url: ""}] else [
        {url: "/puzlet/puzlet/css/coffeelab.css"}
        {url: "http://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/themes/smoothness/jquery-ui.css", var: "jQuery"}  # Alternative
    ]
    
    # TODO: most of these will become part of puzlet math package.  jquery ui loaded by user?
    scriptResources: [
        #        {url: "/puzlet/js/coffeescript.js"}
        {url: "/puzlet/puzlet/js/acorn.js"}
        {url: "/puzlet/puzlet/js/numeric-1.2.6.js"}
        {url: "/puzlet/puzlet/js/jquery.flot.min.js"}
        {url: "/puzlet/puzlet/js/compile.js"}
        {url: "/puzlet/puzlet/js/jquery.cookie.js"}
        #       {url: "http://code.jquery.com/ui/1.9.2/jquery-ui.min.js", var: "jQuery.ui"}
        {url: "http://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/jquery-ui.min.js", var: "jQuery.ui"}   # Alternative
        # {url: "http://ajax.googleapis.com/ajax/libs/jquerymobile/1.4.3/jquery.mobile.min.js"}
    ]
    # {url: "http://ajax.googleapis.com/ajax/libs/jquerymobile/1.4.3/jquery.mobile.min.css"}
    
    constructor: (@render, @done) ->
        @resources = $blab.resources #new Resources
        #@publicInterface()
        @resources.init => @loadCssAndScripts => @loadResourceList3 => @done()
        #@loadCoreResources => @loadCssAndScripts => @loadResourceList3 => @done()
#        @loadCoreResources => @loadCssAndScripts => @loadResourceList2 => @loadHtmlCss => @loadScripts => @done()
        #        @loadCoreResources => @loadGitHub => @loadResourceList => @loadHtmlCss => @loadScripts => @loadAce => @done()
    
    # Dynamically load and run jQuery and Wiky.
    OLD_loadCoreResources: (callback) ->
        @resources.add @coreResources1  # Could this be part of resources boot?
        @resources.loadUnloaded =>
            @resources.loadGitHubFile =>
                @resources.add @coreResources2
                @resources.loadUnloaded =>
                    callback?()
    
    # Initiate GitHub object and load Gist files - these override blab files.
    OLD_loadGitHub: (callback) ->
        @github = new GitHub @resources
        @github.loadGist callback
    
    # Prepend /puzlet/css/puzlet.css to list; prepend script resources (CoffeeScript compiler; math).
    # TODO: Some of these will wind up in resources.coffee.
    loadCssAndScripts: (callback) ->
        @resources.add @htmlResources
        @resources.add @scriptResources
        @resources.loadUnloaded => callback?()
        
    # Load and parse resources.json.  (Need jQuery to do this; uses ajax $.get.)
    # Get ordered list of resources (html, css, js, coffee).
    OLD_loadResourceList: (callback) ->
        list = @resources.add @resourcesList
        @resources.loadUnloaded =>
            @resources.add @htmlResources
            @resources.add @scriptResources
            listResources = JSON.parse list.content
            for r in listResources
                spec = if typeof r is "string" then {url: r} else r
                @resources.add spec
            callback?()
    
    OLD_loadResourceList2: (callback) ->
        p = (code) -> "resources = (obj) -> $blab.resources.processSpec obj, 'main'\n"+code
        res = @resources.add(url: @resourcesList2.url, preProcess: p)
        @resources.loadUnloaded =>
            res.compile()   # TODO: callback?
            callback?()
            
    loadResourceList3: (callback) ->
        @resources.loadFromSpecFile
            url: @resourcesList2.url
            callback: callback
    
    # Async load html and css:
    #   * all html via ajax.
    #   * external css via <link>; auto-appended to dom as soon as resource loaded.
    #   * blab css via ajax; auto-appended to dom (inline) after *all* html/css loaded.
    # After all html/css loaded, render html via Wiky.
    # html and blab css available as source to be edited in browser.
    OLD_loadHtmlCss: (callback) ->
        @resources.load ["html", "css"], =>
            @render html.content for html in @resources.select("html")
            callback?()
    
    # Async load js and coffee; and py/m:
    #   * external js via <script>; auto-appended to dom, and run.
    #   * blab js and all coffee via ajax; auto-appended to dom (inline) after *all* js/coffee loaded.
    #   * py/m via ajax; no action loading.
    # After all scripts loaded: 
    #   * compile each coffee file, with post-js processing if not #!vanilla.
    #   * append JS (blab js or compiled coffee) to dom: external js (from coffee) first, then current blab js.
    # coffee and blab js available as source to be edited in browser.
    # (Loading scripts after HTML/CSS improves html rendering speed.)
    # Note: for large JS file (even 3rd party), put in repo without gh-pages (web page).
    OLD_loadScripts: (callback) ->
        @resources.load ["json", "js", "coffee", "py", "m", "svg", "txt"], =>
            console.log "*******RESOURCES", @resources
            # Before Ace loaded, compile any CoffeeScript that has no associated eval box.
            @compileCoffee (coffee) ->
                not coffee.hasEval() and not coffee.spec.orig.doEval
            callback?()
    
    loadAce: (callback) ->
        load = (resources, callback) =>
            @resources.add resources
            @resources.load ["js", "css"], => callback?()
        new Ace.Resources load, =>
            @resources.render()  # Render Ace editors
            @resources.compileCoffee (coffee) -> coffee.hasEval()  # Compile any CoffeeScript that has associated eval box.
            callback?()
    
    OLD_compileCoffee: (coffeeFilter) ->
        # ZZZ do external first; then blabs.
        filter = (resource) -> resource.isType("coffee") and coffeeFilter(resource)
        coffee.compile() for coffee in @resources.select filter
        
    OLD_publicInterface: ->
        #$blab.resources = @resources
        $blab.loadJSON = (url, callback) => @resources.loadJSON(url, callback)
        $blab.resource = (id) => @resources.getContent id


