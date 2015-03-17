###
TODO: if localhost, try loading resource locally first.  if fails, from github.
support {css: "..."} in resources.coffee
###

console.log "LOADER"

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



class Loader
    
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
    
    coreResources: [
        #       {url: "http://code.jquery.com/jquery-1.8.3.min.js", var: "jQuery"}
        {url: "http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js", var: "jQuery"}  # Alternative
        {url: "/puzlet/puzlet/js/google_analytics.js"}
        #       {url: "http://code.jquery.com/ui/1.9.2/themes/smoothness/jquery-ui.css", var: "jQuery"}
        {url: "http://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/themes/smoothness/jquery-ui.css", var: "jQuery"}  # Alternative
        {url: "/puzlet/puzlet/js/coffeescript.js"}  # TODO: get from coffeescript repo
        {url: "/puzlet/coffeescript/compiler.js"}
        # {url: "http://localhost:8000/puzlet/coffeescript/compiler.js"}  # TODO: FIX!!!
        {url: "/puzlet/puzlet/js/wiky.js", var: "Wiky"}
    ]
    
    resourcesList: {url: "resources.json"}
    resourcesList2: {url: "resources.coffee"}
    
    htmlResources: if window.blabBasic then [{url: ""}] else [
        {url: "/puzlet/puzlet/css/coffeelab.css"}
    ]
    
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
        @blabLocation = Blab.location
        @resources = new Resources @blabLocation
        @publicInterface()
        @loadCoreResources => @loadResourceList2 => @loadHtmlCss => @loadScripts => @done()
#        @loadCoreResources => @loadGitHub => @loadResourceList => @loadHtmlCss => @loadScripts => @loadAce => @done()
    
    # Dynamically load and run jQuery and Wiky.
    loadCoreResources: (callback) ->
        @resources.add @coreResources
        @resources.loadUnloaded =>
            callback?()
    
    # Initiate GitHub object and load Gist files - these override blab files.
    loadGitHub: (callback) ->
        @github = new GitHub @resources
        @github.loadGist callback
    
    # Load and parse resources.json.  (Need jQuery to do this; uses ajax $.get.)
    # Get ordered list of resources (html, css, js, coffee).
    # Prepend /puzlet/css/puzlet.css to list; prepend script resources (CoffeeScript compiler; math).
    loadResourceList: (callback) ->
        list = @resources.add @resourcesList
        @resources.loadUnloaded =>
            @resources.add @htmlResources
            @resources.add @scriptResources
            listResources = JSON.parse list.content
            for r in listResources
                spec = if typeof r is "string" then {url: r} else r
                @resources.add spec
            callback?()
            
    loadResourceList2: (callback) ->
        res = @resources.add(url: @resourcesList2.url, doEval: true)
        @resources.loadUnloaded =>
            res.compile()
            #console.log "COFFEE", res
            @resources.add @htmlResources
            @resources.add @scriptResources
            
            for result in res.resultArray
                if typeof result is "string" and result.length
                    @resources.add {url: result}
            callback?()
    
    # Async load html and css:
    #   * all html via ajax.
    #   * external css via <link>; auto-appended to dom as soon as resource loaded.
    #   * blab css via ajax; auto-appended to dom (inline) after *all* html/css loaded.
    # After all html/css loaded, render html via Wiky.
    # html and blab css available as source to be edited in browser.
    loadHtmlCss: (callback) ->
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
    loadScripts: (callback) ->
        @resources.load ["json", "js", "coffee", "py", "m", "svg", "txt"], =>
            # Before Ace loaded, compile any CoffeeScript that has no assocaited eval box.
            @compileCoffee (coffee) ->
                not coffee.hasEval() and not coffee.spec.orig.doEval
            callback?()
    
    loadAce: (callback) ->
        load = (resources, callback) =>
            @resources.add resources
            @resources.load ["js", "css"], => callback?()
        new Ace.Resources load, =>
            @resources.render()  # Render Ace editors
            @compileCoffee (coffee) -> coffee.hasEval()  # Compile any CoffeeScript that has associated eval box.
            callback?()
    
    compileCoffee: (coffeeFilter) ->
        # ZZZ do external first; then blabs.
        filter = (resource) -> resource.isType("coffee") and coffeeFilter(resource)
        coffee.compile() for coffee in @resources.select filter
        
    publicInterface: ->
        $blab.resources = @resources
        $blab.loadJSON = (url, callback) => @resources.loadJSON(url, callback)
        $blab.resource = (id) => @resources.getContent id


###
class BaseHost
    
    @n: null
    @match: (hostName) -> hostName is @n
    @nameParts: (hostName) -> hostName.split "."
    
    constructor: (@hostName) ->
    
    
class LocalHost extends BaseHost
    
    @n: "localhost"
    
    constructor: ->
    
    
class PuzletHost extends BaseHost
    
    @n: "puzlet.org"


class GitHubHost extends BaseHost
    
    @n: "org.github.io"
    @match: (hostName) ->
        p = @nameParts hostName
        q = @nameParts @n
        p.length is 3 and p[1] is q[1] and p[2] is q[2]  # Alternative: regex match


class GitHubApiHost extends BaseHost
    
    @n: "api.github.com"
    
    
Hosts = [LocalHost, PuzletHost, GitHubHost, GitHubApiHost]
hostFactory = (hostName) ->
    for Host in Hosts
        return new Host(hostName) if Host.match hostName
    return null
    
#Host = hostFactory 
###
        
        
###
*******SPECIFICATION*******
        
===Supported URLs for current blab location===
http://localhost:port/org/repo (note: repo could be org.github.io)
http://puzlet.org
http://puzlet.org/repo
http://org.github.io
http://org.github.io/repo
(We could also support subfolders)

From these, we derive:
org, repo names of current page (index.html).

===For resources.coffee, support these URLs===

File extension affects whether resource is linked or inlined.
JS/CSS files are linked (not inlined), unless they come from current blab (then they are inlined).
All other file types are loaded via Ajax (if possible), and inlined.
Also need {css/js: generalUrl}.

---General URLs---
Must begin with http:// or //
(No special interpretation of org/repo.)

http://general.com/path/to/file.ext (general URL)
http://puzlet.org/org/repo/path/to/file.ext
http://org.github.io/repo/path/to/file.ext
http://rawgit ...

Not supported. Use org/repo approach below instead.  Could support for backward compatibility?
http://api.github.com/...

---Special resource identifiers---
Load locally if localhost and file available; otherwise get from github.

/org/repo/path/to/file.ext 
path/to/file.ext (use current page's host org/repo)

###


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
        @url.indexOf("http://") is 0 or @url.indexOf("//") is 0
        
    subFolder: (filePathIdx) ->
        s = @path[(filePathIdx)..-2].join("/")
        if s then "/"+s else ""


class BlabLocation extends URL
    
    constructor: (@url=window.location.href) ->
        
        super @url
        
        # http://localhost:port/org/repo
        if @hostname is "localhost"
            @owner = @path[0]
            @repoIdx = 1
        
        # http://puzlet.org/repo or http://puzlet.org
        if @hostname is "puzlet.org"
            @owner = "puzlet"
            @repoIdx = 0
        
        # http://org.github.io/repo or http://org.github.io
        if @host.length is 3 and @host[1] is "github" and @host[2] is "io"
            @owner = @host[0]
            @repoIdx = 0
        
        if @hasPath
            @repo = @path[@repoIdx]
            @subf = @subFolder(@repoIdx + 1)
        else
            @repo = null
            @subf = null
        
        @source = "https://github.com/#{@owner}/#{@repo ? ''}" if @owner
        

# TODO: rename
class XResourceLocation extends URL
    
    branch: "gh-pages"  # ZZZ need to get branch - could be master or something else besides gh-pages.
    
    constructor: (@url) ->
        
        super @url
        
        @currentBlab = new BlabLocation  # TODO cache (or make class prop?)
        
        if @onWeb()
            # http://... or //...
            @webResource()
        else
            # /org/repo/path/to/file.ext or # path/to/file.ext
            @blabResource()
    
    webResource: ->
        @owner = null
        @repo = null
        @subf = @subfolder(0)  # Not used
        @inBlab = false
        @source = @url
        
    blabResource: ->
        
        fullPath = (@url.indexOf("/") isnt -1)
        
        if fullPath
            # /org/repo/path/to/file.ext
            @owner = @path[0]
            @repo = @path[1]
            @subf = @subfolder(2)
        else
            # path/to/file.ext
            # TODO: can we get these from @host?
            @owner = @currentBlab.owner
            @repo = @currentBlab.repo
            @subf = @subfolder(0)
        
        @inBlab = @owner is @currentBlab.owner and @repo is @currentBlab.repo
            
        @source = "https://github.com/#{@owner}/#{@repo}#{@subf}" + (if @file then "/blob/#{@branch}/#{@file}" else "")
        @linkedUrl "https://#{@owner}.github.io/#{@repo}#{@subf}/#{@file}"
        @apiUrl = "https://api.github.com/repos/#{@owner}/#{@repo}/contents#{@subf}" + (if @file then "/#{@file}" else "")


testBlabLocation = ->
    
    loc = (url) -> new BlabLocation url
    
    l = loc null
    console.log "&&&&&&&&", l
    
    l = loc "http://puzlet.org/repo/path/to"
    console.log "&&&&&&&&", l
    
    l = loc "http://org.github.io/repo/path"
    console.log "&&&&&&&&", l
    
    l = loc "http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js"
    console.log "&&&&&&&&", l
    
testBlabLocation()


class BaseResourceLocation
    
    constructor: (@url=window.location.href) ->
    
        @a = document.createElement "a"
        @a.href = @url
    
        # URL components
        @hostname = @a.hostname
        @pathname = @a.pathname
        @search = @a.search 
        #@getGistId()
        
        @host = @hostname.split "."
        @path = if @pathname then @pathname.split("/")[1..] else []
        # TODO: perhaps eliminate first element of path?  always ""?
        
        @hasPath = @path.length>0
        
    # TODO: need more stringent match
    specOwner: ->
        @hasPath and (@url.indexOf("/") isnt -1) and not (@hasWebUrl())
    
    # TODO: need more stringent match
    hasWebUrl: ->
        @url.indexOf("//") is 0 or @url.indexOf("http://") is 0  # TODO: regex
        
    #currentLocation: -> resourceLocationFactory()
    
    file: ->
        if @fileExt() then @path[-1..][0] else null  # Does specOwner have influence?
            
    fileExt: ->
        match = if @hasPath then @pathname.match /\.[0-9a-z]+$/i else null
        if match?.length then match[0].slice(1) else null
    

class WebResourceLocation extends BaseResourceLocation
    
    source: -> @url
    
    props: ->
        obj: this
        file: @file()
        source: @source()
    
    
class XBlabResourceLocation extends BaseResourceLocation
    
    # Abstract class
    
    owner: ->  # set by subclass
        
    repoIdx: null  # set by subclass
    
    repo: -> @path[@repoIdx]
    
    subf: ->
        s = @path[(@repoIdx+1)..-2].join("/")
        if s then "/"+s else ""

    #s: -> if @subf() then "/#{@subf()}" else ""  # Subfolder path string
    
    branch: -> "gh-pages"  # ZZZ bug: need to get branch - could be master or something else besides gh-pages.
    
    # TODO: under component github object?
    source: -> "https://github.com/#{@owner()}/#{@repo()}#{@subf()}" + (if @file() then "/blob/#{@branch()}/#{@file()}" else "")
    apiUrl: -> "https://api.github.com/repos/#{@owner()}/#{@repo()}/contents#{@subf()}" + (if @file then "/#{@file()}" else "")
    linkedUrl: -> "https://#{@owner()}.github.io/#{@repo()}#{@subf()}/#{@file()}"
    
    inCurrentBlab: ->
        # TODO: use this in resource factory
        current = Blab.location #@currentLocation()
        current.owner() is @owner() and current.repo() is @repo()
    
    props: ->
        obj: this
        owner: @owner()
        repo: @repo()
        subf: @subf()
        file: @file()
        source: @source()
        apiUrl: @apiUrl()
        linkedUrl: @linkedUrl()
        

class AbsBlabResourceLocation extends XBlabResourceLocation
    
    # url = /org/repo/path/to/file.ext
    
    owner: -> @path[0]
    
    repoIdx: 1


class LocalResourceLocation extends AbsBlabResourceLocation
    
    # url = http://localhost:port/org/repo/path/to/file


class RelBlabResourceLocation extends XBlabResourceLocation
    
    # path = repo/path/to/file.ext
    
    owner: ->  # set by subclass
    
    repoIdx: 0


class CurrentBlabResourceLocation extends RelBlabResourceLocation
    
    # url = path/file.ext
    
    owner: -> Blab.location.owner() #@currentLocation().owner


class PuzletResourceLocation extends RelBlabResourceLocation
    
    # url = http://puzlet.org/repo/path/to/file
    
    owner: -> "puzlet"

    
class GitHubResourceLocation extends RelBlabResourceLocation
    
    # url = http://org.github.io/repo/path/file.ext
    
    owner: -> @host[0]
    
    
resourceLocationFactory = (url=window.location.href) ->
    
    base = new BaseResourceLocation url
    hostname = base.hostname
    host = base.host
    specOwner = base.specOwner()
    hasWebUrl = base.hasWebUrl()
    
    # TODO: github api url?
    
    if specOwner
        return new AbsBlabResourceLocation url
    else if not hasWebUrl
        return new CurrentBlabResourceLocation url
    else if hostname is "localhost"
        return new LocalResourceLocation url
        # Note: local resource is the default.  May wind up from GitHub.
    else if hostname is "puzlet.org"
        return new PuzletResourceLocation url
    else if host.length is 3 and host[1] is "github" and host[2] is "io"
        return new GitHubResourceLocation url
    else
        return new WebResourceLocation url


locationTests = ->
    
    l = resourceLocationFactory "/org/repo/path/to/file.ext"
    console.log "&&&&&&&&", l.props()
    
    l = resourceLocationFactory "http://puzlet.org/repo/path/to/file.ext"
    console.log "&&&&&&&&", l.props()
    
    l = resourceLocationFactory "http://org.github.io/repo/path/file.ext"
    console.log "&&&&&&&&", l.props()
    
    l = resourceLocationFactory "http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js"
    console.log "&&&&&&&&", l.props()
    
    
#locationTests()




class ResourceLocation
    
    # This does not use jQuery. It can be used for before JQuery loaded.
    
    # ZZZ Handle github api path here.
    # ZZZ Later, how to support custom domain for github io?
    
    ###
    Locations:
    localhost:8000/org/repo/path
    puzlet.org/repo/path
    org.github.io/repo/path
    /org/repo/path
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
        


class Resource
    
    constructor: (@spec) ->
        # ZZZ option to pass string for url
        @location = @spec.location ? new ResourceLocation @spec.url
        @url = @location.url
        @fileExt = @spec.fileExt ? @location.fileExt
        @id = @spec.id
        @loaded = false
        @head = document.head
        @containers = new ResourceContainers this
    
    load: (callback, type="text") ->
        # Default file load method.
        # Uses jQuery.
        
        # Load Gist
        if @spec.gistSource
            @content = @spec.gistSource
            @postLoad callback
            return
        
        thisHost = window.location.hostname
        console.log "location", @location
        if (@location.host isnt thisHost or @location.isGitHub) and @location.apiUrl
            # Foreign file - load via GitHub API.  Uses cache.
            console.log "foreign"
            url = @location.apiUrl
            type = "json"
            process = (data) ->
                content = data.content.replace(/\s/g, '')  # Remove whitespace. Fixes parsing issue for Safari.
                atob(content)
        else
            # Regular load.  Doesn't use cache.  type as specified in call.
            url = @url+"?t=#{Date.now()}"
            process = null
            
        success = (data) =>
            @content = if process then process(data) else data
            @postLoad callback
            
        $.get(url, success, type)
        
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


# ZZZ needed?
class EditorContainer
    
    constructor: (@resource, @div) ->
        @node = new Ace.EditorNode @div, @resource
        
    updateResource: ->
        # ZZZ need event/listeners here for other related containers.
        @resource.update(@node.code())


class EvalContainer
    
    constructor: (@resource, @div) ->
        @node = new Ace.EvalNode @div, @resource
        
    getContainer: ->
        @node.container
    

        
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
        @script = document.createElement "script"
        @script.setAttribute "type", "text/javascript"
        @head.appendChild @script
        @script.onload = => @postLoad callback
        #@script.onerror = => console.log "Load error: #{@url}"
        
        t = Date.now()
        # ZZZ need better way to handle caching
        cache = @url.indexOf("/puzlet/js") isnt -1 or @url.indexOf("http://") isnt -1  # ZZZ use ResourceLocation
        if @location.isGitHub and @location.linkedUrl
            @script.setAttribute "src", @location.linkedUrl
        else
            @script.setAttribute "src", @url+(if cache then "" else "?t=#{t}")
        #@script.setAttribute "data-url", @url


class CoffeeResource extends Resource
    
    load: (callback) ->
        super =>
            spec = {id: @url}
            @compiler = if @hasEval() or @spec.orig.doEval then $coffee.evaluator(spec) else $coffee.compiler(spec)
            callback?()
            
    compile: ->
        $blab.evaluatingResource = this
        @compiler.compile @content
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
    
    constructor: (@blabLocation, @getGistSource) ->
    
    create: (spec) ->
        
        return null if @checkExists spec
        
        if spec.url
            url = spec.url
        else
            {url, fileExt} = @extractUrl spec
        #console.log "URL", spec, url
#        url = @modifyPuzletUrl url
        location = new ResourceLocation url
        fileExt ?= location.fileExt
        
        spec =
            id: spec.id
            location: location
            fileExt: fileExt
            gistSource: @getGistSource(url)
            orig: spec  # TODO: hack
        
        subTypes = @resourceTypes[fileExt]
        return null unless subTypes
        if subTypes.all?
            resource = new subTypes.all spec
        else
            subtype = switch
                # TODO: !!!!!!!!!! location.inBlab is bug
                when location.inBlab then "blab"  # File in current blab
                when location.isGitHubApi then "api"  # Use GitHub API
                else "ext"  # External file
            resource = new subTypes[subtype](spec)
        resource
    
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
    
    # TODO: not needed?
    modifyPuzletUrl: (url) ->
        # resources.json can use shorthand /puzlet/...
        # This function makes it:
        #    http://puzlet.org/puzlet/... (on puzlet server) or
        #    /puzlet/puzlet/... (local dev).
        puzletUrl = "http://puzlet.org"
        @puzlet ?= if document.querySelectorAll("[src='#{puzletUrl}/puzlet/js/puzlet.js']").length then puzletUrl else null
        puzletResource = url.match("^/puzlet")?.length
        if puzletResource
            url = if @puzlet then @puzlet+url else "/puzlet"+url
        url


class Resources
    
    constructor: (@blabLocation) ->
        @resources = []
        @factory = new ResourceFactory @blabLocation, (url) => @getGistSource url
        @changed = false
    
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


class Blab
    
    @location: resourceLocationFactory()
    

window.$blab = {}  # Exported interface.  
render = ->
ready = ->
new Loader(render, ready)

#new Blab

