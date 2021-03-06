class Blab
	
	constructor: ->
		@publicInterface()
		@location = new ResourceLocation  # For current page
		window.blabBasic = window.blabBasic? and window.blabBasic
		@page = if window.blabBasic then (new BasicPage(@location)) else (new Page(@location))
		render = (wikyHtml) => @page.render wikyHtml
		ready = => @page.ready @loader.resources
		@loader = new Loader @location, render, ready
		$pz.renderHtml = => @page.rerender()
	
	publicInterface: ->
		window.$pz = {}
		window.$blab = {}  # Exported interface.
		window.console = {} unless window.console?
		window.console.log = (->) unless window.console.log?
		$pz.AceIdentifiers = Ace.Identifiers
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
		#		{url: "http://code.jquery.com/jquery-1.8.3.min.js", var: "jQuery"}
		{url: "http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js", var: "jQuery"}  # Alternative
		{url: "/puzlet/js/google_analytics.js"}
		#		{url: "http://code.jquery.com/ui/1.9.2/themes/smoothness/jquery-ui.css", var: "jQuery"}
		{url: "http://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/themes/smoothness/jquery-ui.css", var: "jQuery"}  # Alternative
		{url: "/puzlet/js/wiky.js", var: "Wiky"}
	]
	
	resourcesList: {url: "resources.json"}
	
	htmlResources: if window.blabBasic then [{url: ""}] else [
		{url: "/puzlet/css/coffeelab.css"}
	]
	
	scriptResources: [
		{url: "/puzlet/js/coffeescript.js"}
		{url: "/puzlet/js/acorn.js"}
		{url: "/puzlet/js/numeric-1.2.6.js"}
		{url: "/puzlet/js/jquery.flot.min.js"}
		{url: "/puzlet/js/compile.js"}
		{url: "/puzlet/js/jquery.cookie.js"}
		#		{url: "http://code.jquery.com/ui/1.9.2/jquery-ui.min.js", var: "jQuery.ui"}
		{url: "http://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/jquery-ui.min.js", var: "jQuery.ui"}   # Alternative
		# {url: "http://ajax.googleapis.com/ajax/libs/jquerymobile/1.4.3/jquery.mobile.min.js"}
	]
	# {url: "http://ajax.googleapis.com/ajax/libs/jquerymobile/1.4.3/jquery.mobile.min.css"}
	
	constructor: (@blabLocation, @render, @done) ->
		@resources = new Resources @blabLocation
		@publicInterface()
		@loadCoreResources => @loadGitHub => @loadResourceList => @loadHtmlCss => @loadScripts => @loadAce => @done()
	
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
			@compileCoffee (coffee) -> not coffee.hasEval()
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



class BasicPage
	
	constructor: (@blabLocation) ->
		@doneFirstHtml = false
	
	render: (wikyHtml) ->
		console.log "render"
		@mainContainer()
		#console.log("HTML",  Wiky.toHtml(wikyHtml))
#		@container.append Wiky.toHtml(wikyHtml)
		new PageTitle unless @doneFirstHtml
		@doneFirstHtml = true
		
	ready: (@resources) ->
		console.log "ready"
		#console.log @resources
		new ResourceImages @resources
		new ThumbImages
		new SlideDeck
		new MathJaxProcessor  # ZZZ should be after all html rendered?
		new Notes
		new FavIcon
#		new GithubRibbon @container, @blabLocation
#		new SaveButton @container, -> $.event.trigger "saveGitHub"
		new GoogleAnalytics
		@scrollToHashSection()
		
	rerender: ->
		@empty()
		@doneFirstHtml = false
		@render html.content for html in @resources.select("html")
		@resources.render()  # Render Ace editors
		resource.compile() for resource in @resources.select "coffee"  # Compile and run all CoffeeScript
		$.event.trigger "htmlOutputUpdated"
	
	mainContainer: ->
		@container = $ "#container"
	
	empty: ->
		@container.empty()
	
	scrollToHashSection: ->
		hash = window.location.hash
		return if not hash
		section = $ "#"+hash.slice(1)
		return unless section.length
		$(document.body).animate(scrollTop: section.offset().top, 0)
	
	

class Page
	
	constructor: (@blabLocation) ->
		@doneFirstHtml = false
		
		#$pz.event.mathjaxProcessed.on (=> @scrollToHashSection())
		#$(window).on "hashchange", (=> @scrollToHashSection())
	
	render: (wikyHtml) ->
		console.log "render"
		@mainContainer()
		#console.log("HTML",  Wiky.toHtml(wikyHtml))
		@container.append Wiky.toHtml(wikyHtml)
		new PageTitle unless @doneFirstHtml
		@doneFirstHtml = true
		
	ready: (@resources) ->
		console.log "ready"
		#console.log @resources
		new ResourceImages @resources
		new ThumbImages
		new SlideDeck
		new MathJaxProcessor  # ZZZ should be after all html rendered?
		new Notes
		new FavIcon
		new GithubRibbon @container, @blabLocation
		new SaveButton @container, -> $.event.trigger "saveGitHub"
		new GoogleAnalytics
		@scrollToHashSection()
		
	rerender: ->
		@empty()
		@doneFirstHtml = false
		@render html.content for html in @resources.select("html")
		@resources.render()  # Render Ace editors
		resource.compile() for resource in @resources.select "coffee"  # Compile and run all CoffeeScript
		$.event.trigger "htmlOutputUpdated"
	
	mainContainer: ->
		return if @container?
		@container = $ "#blab_container"
		unless @container.length
			@container = $ "<div>", id: "blab_container"
			#@container.hide()
			$(document.body).append @container
			#@container.show()  # ZZZ should show only after all html rendered - need another event.
	
	empty: ->
		@container.empty()
	
	scrollToHashSection: ->
		hash = window.location.hash
		return if not hash
		section = $ "#"+hash.slice(1)
		return unless section.length
		$(document.body).animate(scrollTop: section.offset().top, 0)


class FavIcon
	
	constructor: ->
		icon = $ "<link>"
			rel: "icon"
			type: "image/png"
			href: "http://puzlet.org/puzlet/images/favicon.ico"
		$(document.head).append icon


class PageTitle
	
	constructor: ->
		headings = $ ":header"
		return unless headings.length
		$blab.title = headings[0].innerHTML
		#matches = wikyHtml.match /[^|\n][=]{1,6}(.*?)[=]{1,6}[^a-z0-9][\n|$]/
		#$blab.title = matches[1] if matches?.length
		document.title = $blab.title


class GithubRibbon
	
	constructor: (@container, @location) ->
	    
		return if $blab.noGitHubRibbon
		
		# Link depends on server:
		# For localhost use path. E.g. "/stemblab.github.io/gifs/gallery/"
		# For github use URL. E.g. "http://stemblab.github.io/gifs/gallery"
		# Both map to "http://github.com/stemblab/gifs" (sub-blabs ignored).
		
		if @location.host is "localhost"
			s = @location.path.split("/")
			@link = "http://github.com/"+s[1].split(".")[0]+"/"+s[2]
		else
			s = @location.url.split("/")
			@link = "http://github.com/"+s[2].split(".")[0]+"/"+s[3]
		
		#return unless @container
		
		src = "https://camo.githubusercontent.com/365986a132ccd6a44c23a9169022c0b5c890c387/68747470733a2f2f73332e616d617a6f6e6177732e636f6d2f6769746875622f726962626f6e732f666f726b6d655f72696768745f7265645f6161303030302e706e67"
		html = """
			<a href="#{@link}" id="ribbon" style="opacity:0.2">
			<img style="position: absolute; top: 0; right: 0; border: 0;" src="#{src}" alt="Fork me on GitHub" data-canonical-src="https://s3.amazonaws.com/github/ribbons/forkme_right_red_aa0000.png"></a>
		"""
		@container.append(html)
		@ribbon = $("#ribbon")
		setTimeout (=> @ribbon.fadeTo(400, 1).fadeTo(400, 0.2)), 2000
		
		$(document).on "codeNodeChanged", => @ribbon.hide()
		$(document).on "codeSaved", => @ribbon.show()


class MathJaxProcessor
	
	source: "http://cdn.mathjax.org/mathjax/2.4-latest/MathJax.js?config=default"
#	source: "http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=default"
		# default, TeX-AMS-MML_SVG, TeX-AMS-MML_HTMLorMML
	#outputSelector: ".code_node_html_output"
	mode: "HTML-CSS"  # HTML-CSS, SVG, or NativeMML
	
	constructor: ->  # ZZZ param via mode?
	
		#return # DEBUG
		
		container = $("#container")
		hasBodyContainer = container.length and container.parent().is("body")
		@outputId = if hasBodyContainer then "container" else "blab_container"
		
#		@outputId = "codeout_html"
		
		#MathJaxProcessor?.mode = "SVG"
		
		#@mode = "SVG"
		# return if $blab.mathjaxConfig already exists?
		
		$blab.mathjaxConfig = =>
			$.event.trigger "mathjaxPreConfig"
			window.MathJax.Hub.Config
				jax: ["input/TeX", "output/#{@mode}"]
				tex2jax: {inlineMath: [["$", "$"], ["\\(", "\\)"]], ignoreClass: "tex2jax_ignore"}
				TeX: {equationNumbers: {autoNumber: "AMS"}}
				elements: [@outputId, "blab_refs"]
				showProcessingMessages: false
				#"HTML-CSS": {scale: 100}
				MathMenu:
					showRenderer: true
					
			# Fix for chrome/mathjax vertical line at end of math.
			MathJax.Hub.Register.StartupHook("End", ->
				$('.math>span').css("border-left-color", "transparent")
			)
			
			window.MathJax.HTML.Cookie.Set "menu", renderer: @mode
			#console.log "mathjax", window.MathJax.Hub
		
		configScript = $ "<script>",
			type: "text/x-mathjax-config"
			text: "$blab.mathjaxConfig();"
		mathjax = $ "<script>",
			type: "text/javascript"
			src: @source
		$("head").append(configScript).append(mathjax)
		
		$(document).on "htmlOutputUpdated", => @process()
		
	process: ->
		return unless MathJax?
		@id = @outputId  # Only one node.  ZZZ or do via actual dom element?
		#console.log "mj id", @id
		Hub = MathJax.Hub
		queue = (x) -> Hub.Queue x
		queue ["PreProcess", Hub, @id]
		queue ["Process", Hub, @id]
    queue (->
      # Fix MathJax 2.4 issue - vertical border on right side on math
      $('.math>span').css("border-left-color", "transparent")
    )
		configElements = => Hub.config.elements = [@id]
		queue configElements


class GoogleAnalytics
	
	constructor: ->
		@codeChanged = false
		@title = $blab.title
		@track "codeNodeChanged", "edit", "firstEdit", @title, (=> not @codeChanged), (=> @codeChanged = true)
		@track "runCode", "runCode", "run", @title
		
	track: (pzEvent, gCat, gEvent, gText, condition=(->true), callback) ->
		$(document).on pzEvent, =>
			#console.log "pzEvent", pzEvent
			_gaq?.push ["_trackEvent", gCat, gEvent, gText] if condition()
			callback?()
	


# Mouseovers notes
class Notes
	
	constructor: ->
		@initTooltip()
		@processText((t) => @init t)
		$(document).on "mathjaxPreConfig", =>
			#MathJax.Hub.signal.Interest (message) ->
			#	console.log "Hub", message
			MathJax.Hub.Register.StartupHook "MathMenu Ready", =>
				@processText((t) => @set t)
			MathJax.Hub.Register.MessageHook "End Process", =>
				@processText((t) => @set t)
		$(document).on "htmlOutputUpdated", => @processText((t) => @init t)
		$(document).tooltip(css: {fontSize: "10pt"})  # ZZZ Use .css instead
	
	
	initTooltip: ->
		$pz.persistentTooltip = (widget) ->
			
			delay = 100
			tId = null
			
			clear = -> if tId then clearTimeout tId
			
			set = ->
				clear()
				tId = setTimeout (-> widget.tooltip "close"), delay
				
			widget.tooltip()  # This is necessary to initialize tooltip for timeout.
			
			widget.on "tooltipopen", (event, ui) ->
				setClose = ->
					tipId = widget.attr "aria-describedBy"
					tip = $ "#"+tipId
					tip.on "click", (-> widget.tooltip "close")
				setTimeout setClose, 100
			
			widget.mouseenter ((evt) -> clear())
			
			widget.mouseleave ((evt) ->
				evt.stopImmediatePropagation()
				#return  # ZZZ DEBUG
				set()
				tipId = widget.attr "aria-describedBy"
				tip = $ "#"+tipId                # Alt (broad): $ ".ui-tooltip-content" 
				tip.on "mouseenter", (-> clear())
				tip.on "mouseleave", (-> set())
			)
	
	
	processText: (method) -> method($ txt) for txt in $ ".pz_text"
	
	init: (t) ->
		if t.attr("title")?
			t.removeAttr "title"
			t.tooltip()
			t.tooltip "destroy"
		$pz.persistentTooltip t
		t.attr title: @html(t)
		
	set: (t) ->
		$pz.persistentTooltip t if not t.data("tooltipset")
		t.tooltip "option", "content", @html(t)
		
	html: (t) ->
		ref = t.attr "ref"
		$("##{ref}").html()


class OpenInTab
	
	# ZZZ not implemented yet.
	
	constructor: ->
	
		@linkedTab = null
		window.openInTab = (id, section) =>
			if not @linkedTab or @linkedTab.closed
				@linkedTab = window.open "?id=#{id}##{section}", "_blank"
			else
				@linkedTab.focus()
				@linkedTab.location.hash = "#"+section


class ResourceImages
	
	constructor: (@resources) ->
		for img in $("img[data-src]")
			$img = $(img)
			r = @resources.select((resource) -> resource.url is $img.data("src"))
			$img.attr src: "data:image/svg+xml;charset=utf-8,"+r[0].content


class ThumbImages
	
	constructor: ->
		@processThumb($ img) for img in $ "pzthumb"
		
	processThumb: (img) ->
		i = @processImg img
		return if not i
		i.attr "title", "Click to see slide"
		i.css
			float: "right"
			cursor: "pointer"
			backgroundImage: "url('http://puzlet.org/puzlet/images/UI_171.png')"
			backgroundRepeat: "no-repeat"
			backgroundPosition: "right top" #"right top"
			backgroundSize: "20px 20px"
		i.attr "height", "250"
		
	processImg: (img) ->
		#return if not img.is ':empty'  # ZZZ need this later?
		i = $ "<img>"
		for attr in img[0].attributes
			name = attr.name
			val = attr.value
			i.attr name, val
		img.append i
		i


new Blab

