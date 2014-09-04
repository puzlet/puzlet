class ResourceLocation
	
	# This does not use jQuery. It can be used for before JQuery loaded.
	
	# ZZZ Handle github api path here.
	# ZZZ Later, how to support custom domain for github io?
	
	constructor: (@url=window.location.href) ->
		
		@a = document.createElement "a"
		@a.href = @url
		
		# URL components
		@host = @a.hostname
		@path = @a.pathname
		@search = @a.search 
		@getGistId()
		
		# Decompose into parts
		hostParts = @host.split "."
		@pathParts = if @path then @path.split "/" else []
		hasPath = @pathParts.length
		
		# Resource host type
		@isLocalHost = @host is "localhost"
		@isPuzlet = @host is "puzlet.org"
		@isGitHub = hostParts.length is 3 and hostParts[1] is "github" and hostParts[2] is "io"
		# Example: https://api.github.com/repos/OWNER/REPO/contents/FILE.EXT
		@isGitHubApi = @host is "api.github.com" and @pathParts.length is 6 and @pathParts[1] is "repos" and @pathParts[4] is "contents"
			
		# Owner/organization
		@owner = switch
			when @isLocalHost and hasPath then @pathParts[1]
			when @isPuzlet then "puzlet"
			when @isGitHub then hostParts[0]
			when @isGitHubApi and hasPath then @pathParts[2]
			else null
		
		# Repo and subfolder path
		@repo = null
		@subf = null
		if hasPath
			repoIdx = switch
				when @isLocalHost then 2
				when (@isPuzlet or @isGitHub) then 1
				when @isGitHubApi then 3
				else null
			if repoIdx
				@repo = @pathParts[repoIdx]
				pathIdx = repoIdx + (if @isGitHubApi then 2 else 1)
				@subf = @pathParts[pathIdx..-2].join "/"
		
		# File and file extension
		match = if hasPath then @path.match /\.[0-9a-z]+$/i else null  # ZZZ dup code - more robust way?
		@fileExt = if match?.length then match[0].slice(1) else null
		@file = if @fileExt then @pathParts[-1..][0] else null
		@inBlab = @file and @url.indexOf("/") is -1
		
		if @gistId
			# Gist
			f = @file?.split "."
			@source = "https://gist.github.com/#{@gistId}" + (if @file then "#file-#{f[0]}-#{f[1]}" else "")
		else if @owner and @repo
			# GitHub repo (or puzlet.org).
			s = if @subf then "/#{@subf}" else ""  # Subfolder path string
			branch = "gh-pages"  # ZZZ bug: need to get branch - could be master or something else besides gh-pages.
			@source = "https://github.com/#{@owner}/#{@repo}#{s}" + (if @file then "/blob/#{branch}/#{@file}" else "")
			@apiUrl = "https://api.github.com/repos/#{@owner}/#{@repo}/contents" + (if @file then "/#{@file}" else "")
		else
			# Regular URL - assume source at same location.
			@source = @url
		
		#console.log "resource", this
		
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
		if @location.host isnt thisHost and @location.apiUrl
			# Foreign file - load via GitHub API.  Uses cache.
			#console.log "foreign"
			url = @location.apiUrl
			type = "json"
			process = (data) -> atob(data.content)
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
		@script = document.createElement "script"
		@script.setAttribute "type", "text/javascript"
		@head.appendChild @script
		@script.onload = => @postLoad callback
		#@script.onerror = => console.log "Load error: #{@url}"
		
		t = Date.now()
		# ZZZ need better way to handle caching
		cache = @url.indexOf("/puzlet/js") isnt -1 or @url.indexOf("http://") isnt -1  # ZZZ use ResourceLocation
		@script.setAttribute "src", @url+(if cache then "" else "?t=#{t}")
		#@script.setAttribute "data-url", @url


class CoffeeResource extends Resource
	
	load: (callback) ->
		super =>
			@Compiler = if @hasEval() then CoffeeCompilerEval else CoffeeCompiler
			@compiler = new @Compiler @location
			callback?()
			
	compile: ->
		$blab.evaluatingResource = this
		@compiler.compile @content
		@resultStr = @compiler.resultStr
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
	
	constructor: (@blabLocation, @getGistSource) ->
	
	create: (spec) ->
		
		return null if @checkExists spec
		
		if spec.url
			url = spec.url
		else
			{url, fileExt} = @extractUrl spec
		url = @modifyPuzletUrl url
		location = new ResourceLocation url
		fileExt ?= location.fileExt
		
		spec =
			id: spec.id
			location: location
			fileExt: fileExt
			gistSource: @getGistSource(url)
		
		subTypes = @resourceTypes[fileExt]
		return null unless subTypes
		if subTypes.all?
			resource = new subTypes.all spec
		else
			subtype = switch
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


#--- CoffeeScript compiler/evaluator ---#

class CoffeeCompiler
	
	constructor: (@location) ->
		@url = @location.url
		@isMain = @location.inBlab
		@head = document.head
	
	compile: (@content) ->
		# ZZZ should this be done via eval, rather than append to head?
		console.log "Compile #{@url}"
		@head.removeChild @element[0] if @findScript()
		@element = $ "<script>",
			type: "text/javascript"
			"data-url": @url
		# ZZZ enhance with try/catch for errors
		js = CoffeeEvaluator.compile @content, @isMain
		@element.text js
		@head.appendChild @element[0]
	
	findScript: ->
		$("script[data-url='#{@url}']").length


class CoffeeCompilerEval
	
	lf: "\n"
	
	constructor: (@location) ->
		@url = @location.url
		@isMain = @location.inBlab
		@evaluator = new CoffeeEvaluator
	
	compile: (@content) ->
		# Eval node exists
		console.log "Compile #{@url} (for eval box)"
		recompile = true
		@resultArray = @evaluator.process @content, @isMain, recompile
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
	@compile = (code, isMain=true, bare=false) ->
		#console.log "@compile isMain", isMain
		CoffeeEvaluator.blabCoffee ?= new BlabCoffee
		js = CoffeeEvaluator.blabCoffee.compile code, isMain, bare
	
	@eval = (code, isMain=true, js=null) ->
		#console.log "@eval isMain", isMain
		# Pass js if don't want to recompile.
		js = CoffeeEvaluator.compile code, isMain unless js
		eval js
		js
	
	constructor: ->
		@js = null
	
	process: (code, isMain=true, recompile=true) -> #, stringify=true) ->
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
			@js = CoffeeEvaluator.eval @evalLines, isMain, js  # Evaluated lines will be assigned to $blab.evaluator.
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
		@blabLocation = @resources.blabLocation
		@hostname = @blabLocation.host
		@blabId = @blabLocation.repo
		@gistId = @blabLocation.gistId
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
		
		resources = @resources.select (resource) -> resource.inBlab()
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

