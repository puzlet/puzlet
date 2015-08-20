###
TODO:
* use full file path instead of subf - is subf by itself ever really needed?
* if localhost, try loading resource locally first.  if fails, from github.
* support {css: "..."} in resources.coffee
* loadJSON broken - Resource.load no longer supports type?
* have local env file so we know whether to try loading locally (localhost or deployed host)?
* for deployed host, may also need to know root folder?
###

console.log "Puzlet loader"

#--- Example resources.coffee ---
# Note that order is important for html rendering order, css cascade order, and script execution order.
# But blab resources can go at top because always loaded after external resources.
# A blab resource can now go directly in <div data-file='...'>, rather than in resources.coffee.

###
resources
  load: [
    "main.html"
    "style.css"
    "bar.js"
    "foo.coffee"
    "main.coffee"
    "/some-org/some-repo/snippet.html",
    "/other-org/other-repo/foo.css",
    "/puzlet/puzlet/js/d3.min.js", # check this
    "http://domain.com/script.js",
    "/org/ode-fixed/ode.coffee"
]    

******* SPECIFICATION *******
        
===Supported URLs for current blab location===
TODO: is stuff below for puzlet bootstrap?
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
        @pathname = "/" if @pathname is "."  # IE fix
        idx = if @pathname.indexOf("/") is 0 then 1 else 0  # IE removes first / from pathname.
        @path = if @pathname then @pathname.split("/")[idx..] else []
        #console.log "====PATH", @url, @pathname, @pathname.split("/"), @path
        
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


class ResourceLocation extends URL
    # Abstract class
        
    # TODO: handle load error
    
    owner: null
    repo: null
    filepath: null
    inBlab: false
    source: null
    gitHub: null
    
    constructor: (@url) ->
        super @url
        # TODO: @filepath?
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
    
    localOrgPath: null
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
            
        #console.log "%%%%% owner/path/blabOwner/url", @owner, @path, @blabOwner, @url
        
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
        @cache = false #not @inBlab and @owner is "puzlet"  # TODO: better way?
        
        #console.log @owner, @repo, @filepath, @loadUrl
        #console.log @gitHub.linkedUrl()
        
        @source = @gitHub.sourcePageUrl()
    
    load: (callback) ->
        #console.log "Blab load #{@url} => #{@loadUrl}"
        url = @loadUrl + "?t=#{Date.now()}"  # No cache
        # Ajax-load method.  TODO: continue if load error.  OR try guthub if localpath load fail
        $.get(url, ((data) -> callback(data)), "text")
    
    fullPath: ->
        @url?.indexOf("/") is 0
        # ZZZ need to check that second char not "/"


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
    
    knownGitHubOrgDomains: [
      {domain: "puzlet.org", org: "puzlet"}
      {domain: "blabr.io", org: "puzlet"}
    ]
    
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
        known = @knownGitHubOrgDomains.filter((d) => @owner is d.org)
#        host = "#{@owner}.github.io"  # Causes 301 response -> puzlet.org
        host = if known.length then known[0].domain else "#{@owner}.github.io"
        #console.log "-------linkedUrl (@owner/known/host)", @owner, known, host 
        "http://#{host}/#{@repo}/#{@path}"
#        "https://#{host}/#{@repo}/#{@path}"
        
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
        @blockPostLoad = false
        @head = document.head
        
    load: (@postLoadCallback) ->
        # Default file load method.
        # Uses jQuery.
        
        source = @spec.orig.source ? @spec.source
        if source?
            @content = source
            # Timeout needed to give same behavior as load.
            # Else issue with @blockPostLoadFromSpecFile in Resources.
            setTimeout (=> @postLoad()), 0
        else
            @location.load((@content) => @postLoad())
    
    postLoad: ->
        return if @blockPostLoad
        @loaded = true
        @postLoadCallback?()
        #callback?()
    
    isType: (type) -> @fileExt is type
    
    update: (@content) ->
        console.log "No update method for #{@url}"
    
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


class MarkdownResource extends Resource


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
    
    load: (@postLoadCallback) ->
        @style = document.createElement "link"
        #@style.setAttribute "type", "text/css"
        @style.setAttribute "rel", "stylesheet"
        t = Date.now()
        @style.setAttribute "href", @loadUrl+"?t=#{t}"
#        @style.setAttribute "href", @url  #+"?t=#{t}"
        #@style.setAttribute "data-url", @url
        
        # Old browsers (e.g., old iOS) don't support onload for CSS.
        # And so we force postLoad even before CSS loaded.
        # Forcing postLoad generally ok for CSS because won't affect downstream dependencies (unlike JS). 
        setTimeout (=> @postLoad()), 0
        #@style.onload = => @postLoad callback
        
        @head.appendChild @style


class JsResourceInline extends ResourceInline
    
    tag: "script"
    #mime: "text/javascript"
    


class JsResourceLinked extends Resource
    
    load: (@postLoadCallback) ->
        @script = document.createElement "script"
        #@script.setAttribute "type", "text/javascript"
        @head.appendChild @script
        @script.onload = => @postLoad()
        @script.onerror = => console.log "Load error: #{@url} #{@loadUrl}, #{@script.getAttribute 'src'}"
        
        src = @loadUrl  # TODO: if this fails, try loading from github
#        src = @url  # TODO: if this fails, try loading from github
        #console.log "JsResourceLinked load", src
        t = if @location.cache then "" else "?t=#{Date.now()}"
        @script.setAttribute "src", src+t


class CoffeeResource extends Resource
    
    @preCompileCode: {}
    
    constructor: (@spec) ->
      super @spec
      @observers =
        preCompile: []
    
    load: (callback) ->
        $.event.trigger("loadCoffeeResource", {resource: this})
        
        super =>
            @doEval = false
            @setCompilerSpec {}
            @mathSpecSet = false
            @compiled = false
            callback?()
            
    setEval: (doEval) ->
      return if @doEval is doEval
      @doEval = doEval
      if @doEval
        @mathSpecSet = false
        @compile()
        
    setCompilerSpec: (spec) ->
        #console.log "+++++++ CoffeeResource.setCompilerSpec", this
        spec.id = @url
        @compiler = if @doEval or @spec.orig.doEval then $coffee.evaluator(spec) else $coffee.compiler(spec)
        @extraLines = spec.extraLines ? (-> "")
            
    compile: (recompile=false) ->
        @setMathSpec()
        #$blab.evaluatingResource = this  # ZZZ to deprecate
        $.event.trigger("preCompileCoffee", {resource: this})
        #recompile = false  # Used only for $coffee.evaluator
        @compiler.compile @content, recompile
        @compiled = true
        if @compiler.result?
          @resultArray = @compiler.resultArray
          @resultStr = @compiler.result?.join("\n") + @extraLines(@resultArray)
        else
          @resultArray = []
          @resultStr = ""
        $.event.trigger("compiledCoffeeScript", {url: @url})
    
    update: (@content) ->
      #console.log "content", @content
      recompile = true
      @compile(recompile)
    
    on: (evt, observer) -> @observers[evt].push observer
    
    setMathSpec: ->
        return unless $mathCoffee? and not @mathSpecSet
        bare = false
        isMain = @inBlab()
        spec =
            compile: (code) => $mathCoffee.compile(@preCompile(code), bare, isMain)
            evaluate: (code, js) => $mathCoffee.evaluate(@preCompile(code), js, isMain)
            extraLines: (resultArray) -> $mathCoffee.extraLines(resultArray)
        @setCompilerSpec spec
        @mathSpecSet = true
        
    preCompile: (code) ->
      preCompileCode = CoffeeResource.preCompileCode
      pc = preCompileCode[@url]
      code = pc.preamble + code + pc.postamble if pc
      code = observer({code}) for observer in @observers.preCompile
      #console.log "Pre-compile code", @url, code
      code
      
    @registerPrecompileCode: (preCompileCode) ->
      for url, pc of preCompileCode
        CoffeeResource.preCompileCode[url] = pc


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
        md: {all: MarkdownResource}
    
    constructor: (@getSource) ->
    
    create: (spec) ->
        
        console.log "LOAD", spec.url
        
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
            source: @getSource(url)
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

class Resources
    
    # jQuery and puzlet.json (if local/deployment) are loaded in Puzlet bootstrap script (//puzlet.org/puzlet.js).
    coreResources: [
        {url: "/puzlet/coffeescript/coffeescript.js"}
        {url: "/puzlet/coffeescript/compiler.js"}
        {url: "/puzlet/puzlet/js/github.js"}
    ]
    
    resourcesSpec: "/puzlet/puzlet/resources.coffee"  # Default
    
    constructor: (spec) ->
        unless window.googleAnalyticsSet
          coreResources.push {url: "/puzlet/puzlet/js/google_analytics.js"}
        @resources = []
        @factory = new ResourceFactory (url) => @getSource?(url)
        @changed = false
        @blockPostLoadFromSpecFile = false
        @observers =
          preload: []
          postload: []
          ready: []
        
    # Load coffeescript compiler and other core resources.
    # Supports preload and postload callbacks (before/after resources.coffee loaded).
    init: (spec) ->
        
        core = (cb) => @addAndLoad @coreResources, cb
        
        getResourcesUrl = =>
          pzAttr = "data-resources"
          pzScript = $("script[#{pzAttr}]")
          if pzScript.length then pzScript.attr(pzAttr) else @resourcesSpec
        
        resources = (cb) =>
            @loadFromSpecFile
                url: getResourcesUrl()
                callback: => cb()
                
        preload = (cb) =>
            @triggerAndWait "preload", [], ->
              spec?.preload?()
              cb()
            
        postload = (cb) =>
            @trigger "postload"
            spec?.postload?()
            cb?()
            
        ready = =>
            console.log "Loaded all resources specified in resources.coffee"
            @trigger "ready"
        
        core -> preload -> resources -> postload -> ready()
    
    addAndLoad: (resourceSpecs, callback) ->
        resources = @add resourceSpecs
        filter = (resource) ->
            for r in resources
                return true if resource.url is r.url
            return false
        @load filter, callback
        #@loadUnloaded callback
        resources
    
    add: (resourceSpecs) ->
        resourceSpecs = [resourceSpecs] unless resourceSpecs.length
        newResources = []
        for spec in resourceSpecs
            resource = @factory.create spec
            continue unless resource
            newResources.push resource
            @resources.push resource
        $.event.trigger "resourcesAdded", {resources: newResources}
        if newResources.length is 1 then newResources[0] else newResources
        
    load: (filter, loaded) ->
        # When are resources added to DOM?
        #   * Linked resources: as soon as they are loaded.
        #   * Inline resources (with appendToHead method): *after* all resources are loaded.
        filter = @filterFunction filter
        resources = @select((resource) -> not resource.loaded and filter(resource))
        resourcesToLoad = resources.length
        if resourcesToLoad is 0
            loaded?([])
            return
        resourceLoaded = (resource) =>
            resourcesToLoad--
            if resourcesToLoad is 0
                @appendToHead filter  # Append to head if the appendToHead method exists for a resource, and if not aleady appended.
                loaded?(resources)
        for resource in resources
            resource.load -> resourceLoaded(resource)
    
    loadUnloaded: (loaded) ->
        # Loads all unloaded resources.
        @load (-> true), loaded
        
    # Load from resources.coffee specification.
    # Get ordered list of resources (html, css, js, coffee).
    loadFromSpecFile: (spec) ->
        url = spec.url
        specFile = @add(url: url)
        @postLoadFromSpecFile = -> spec.callback?()
        
        compile = (code) ->
            code = "resources = (obj) -> $blab.resources.processSpec obj\n\n"+code
            $coffee.compile code
        
        @load ((resource) -> resource.url is url), =>
            specFile.setCompilerSpec compile: compile
            specFile.compile()  # TODO: check valid coffee?
            @loadHtmlCss => @loadScripts =>
              @postLoadFromSpecFile() unless @blockPostLoadFromSpecFile
        
    # Process specification in resources.coffee.
    processSpec: (resources) ->
        console.log "----Process files in resources.coffee"
        for url in resources.load
            @add {url} if typeof url is "string" and url.length
        
    # Load html and css:
    #   * all html via ajax.
    #   * external css via <link>; auto-appended to dom as soon as resource loaded.
    #   * blab css via ajax; auto-appended to dom (inline) after *all* html/css loaded.
    # After all html/css loaded, render html via Wiky.
    # html and blab css available as source to be edited in browser.
    loadHtmlCss: (callback) ->
        @load ["html", "md", "css"], =>
            # TODO: add render
            #@render html.content for html in @resources.select("html")  # TODO: callback for HTMLResource?
            callback?()
    
    # ZZZ not used?
    loadPackages: (callback) ->
        
        loaders = []
        
        # Used in package.coffee to add package resources
        $blab.package = (pkg) =>
            p1 = []
            p2 = []
            for p in pkg
                if p.dependent
                    p2.push p
                else
                    p1.push p
                
            load = (callback) =>
                @addAndLoad p1, =>
                    @addAndLoad p2, callback
            loaders.push load
        
        filter = (resource) -> resource.loadUrl.indexOf("package.coffee") isnt -1
        
        @load filter, (packages) =>
            
            coffee.compile() for coffee in packages
            
            if loaders.length is 0
                callback?()
                return
                
            #console.log "loaders2", loaders2
                
            n = 0
            for load in loaders
                n++
                load ->
                    n--
                    callback?() #if n is 0
    
    
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
            # Before Ace loaded, compile any CoffeeScript.
            # Note that this can cause a double compile/eval if resource is in resources.coffee and specified in <div>.
            @compileCoffee() # (coffee) -> not(coffee.spec.orig.doEval or coffee.compiled)
            callback?()
    
    # TODO: duplicate code?
    compileCoffee: (coffeeFilter) ->
        # ZZZ do external first; then blabs.
        filter = (resource) -> resource.isType("coffee") and not(resource.spec.orig.doEval or resource.compiled)
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
    
    sourceMethod: (@getSource) ->
    
    on: (evt, observer) -> @observers[evt].push observer
    
    trigger: (evt, data) -> observer(data) for observer in @observers[evt]
    
    triggerAndWait: (evt, data, cb) ->
      observers = @observers[evt]
      n = observers.length
      cb() if n is 0
      done = ->
        n--
        cb() if n is 0
      observer(data, done) for observer in observers


#-----------------------------------------------------------------------------#
window.$pz = {}

resources = new Resources

# Public interface.  $blab is defined in Puzlet bootstrap script (//puzlet.org/puzlet.js)
console.log "$blab", $blab

$blab.resources = resources
$blab.load = (r, callback) -> resources.addAndLoad(r, callback)
$blab.loadJSON = (url, callback) => resources.loadJSON(url, callback)
$blab.resource = (id) => resources.getContent id

$blab.CoffeeResource = CoffeeResource
$blab.precompile = (pc) -> CoffeeResource.registerPrecompileCode(pc)

resources.init()

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
