class SlideDeck
	
	constructor: ->
		# Don't create slide deck if no slide source.
		return if not @slideSource()[0]
		@slideContainer = new SlideContainer(
			(disp) => @containerCallback disp,
			(evt) => @keypress evt
		)
		@slidesButton = new SlidesButton(=> @show())
		@createDeck()
		$(document).on "mathjaxPreConfig", =>
			window.MathJax.Hub.Register.StartupHook "MathMenu Ready", =>
				@createDeck()
# ZZZ for sandboxes:
#		$pz.event.mathjaxProcessed.on =>
#			@createDeck()
			#@scrollToHashSection()
#		$pz.event.codeSaved.on => @createDeck()
		# Improvement: do only for html nodes
		#$(window).on('hashchange', => @scrollToHashSection())
		
	slideSource: -> 
		$ ".pz_slide"
	
	createDeck: ->
		# Current slide ref
		current = if @slide then @slide.ref else @first
		# Remove previous slides
		slide.remove() for name, slide of @slides if @slides?
		@slides = {} # MVC - stemweblab
		@slide = null  # Current slide
		@first = null  # First slide ref
		Slide.lastCreated = null
		@createSlide($ source) for source in @slideSource()
		@assignLink($ txt) for txt in $ ".pz_slide_link"
		@assignLink($ txt) for txt in $ ".pz_section"
		@assignLink($ img) for img in $ "pzthumb"
		@assignCodeLink($ img) for img in $ "pzimg"
		@navButtons.remove() if @navButtons?
		if @slideSource().length>1
			@navButtons = new NavButtons @slideContainer.div, 
				((to) => @go to)
		@slidesButton.show()
		@numSlides = Object.keys(@slides).length
		@showSlide current if @slideContainer.displayed
			
	createSlide: (source) ->
		id = source.attr "id"
		section = source.attr "section"
		@first = id if not @first
		@slides[id] = new Slide @slideContainer.div, id, section, 
			Slide.lastCreated, 
			((nodes) => )
#			((nodes) => @slideContainer.setCodeNodes nodes)  # ZZZ Needed for showCode button
		
	assignLink: (t) ->
		ref = t.attr "ref"
		return if not ref or not @slides[ref]
		@slides[ref].addLink t
		t.unbind "click"
		t.click =>
			currentRef = @slide.ref if @slide
			if ref is currentRef
				@slideContainer.toggle()
			else
				@showSlide ref
		tClass = t.attr("class")
		if tClass is "pz_slide_link" or tClass is "pz_section"
			t.attr "title", "Click to see slide"
		
	# ZZZ deprecate?
	assignCodeLink: (img) ->
		codeIds = img.attr "codeids"
		return if not codeIds
		img.unbind "click"
		img.click => 
			ids = codeIds.split ","
			for id in ids
				t = $.trim(id)
				$pz.event.showCode.trigger(id: t)
		
	show: ->
		if not @slide
			@showSlide @first
		else
			@slideContainer.toggle()
			
	showSlide: (ref) ->
		return if not ref
		@slide.show(false) if @slide
		@slide = if @slides[ref] then @slides[ref] else @slides[@first]
		@slide.show()
		if @navButtons
			@navButtons.enable @slide.prev, @slide.next
			@navButtons.setIndex @slide.index, @numSlides
		@slideContainer.show()
			
	containerCallback: (show=true) -> 
		@slide.highlightLinks show if @slide
		@slidesButton.highlight show if @slidesButton
		
	keypress: (evt) ->
		key = evt.keyCode
		disp = @slideContainer.displayed
		keys =
			27: => @show()	# Escape
		if disp
			keys[36] = => @showSlide @first	 # Home or fn-left
			keys[37] = => @go "prev" # Left arrow
			keys[39] = => @go "next" # Right arrow

		for k, f of keys
			if key is parseInt(k)
				evt.preventDefault()
				f()
		if disp and key is 13 and @slide.section?
			if window.location.hash is "#"+@slide.section
				window.location.hash = "" 
			window.location.hash = @slide.section
		
	go: (to) ->
		# to is "prev" or "next"
		slide = @slide[to]
		@showSlide slide.ref if slide


class SlideContainer
	
	constructor: (@displayCallback, @keyCallback) ->
		
		css =
			position: "fixed"
			zIndex: 10
			overflow: "visible" #"auto"
			width: "760px"
			height: "500px"
			bottom: 40 # "20px"
			left: "50%"
			#margin-top: -100px;
			margin: 0
			marginLeft: -380 # Half width "20px"
			background: "#fff"
			opacity: 0.95
			padding: "10px"
			border: "2px solid gray"
			borderRadius: "8px"
			boxShadow: "5px 5px 8px #888888"
			
		parent = $ "#blab_container"  # MVC - stemweblab
		@div = $ "<div>", css: css, id: "pz_slide_deck"
		@div.draggable()
		#@div.resizable()  # Causes drag issues in some browsers.
		parent.append @div
		
		@div.click (-> $(document.activeElement).blur())
		
		$(document.body).keydown((evt) =>
			@keyCallback(evt) #if @displayed
		)
		
		# Show code button
		if false
			@codeNodesButton = new ImageButton @div, 
				"UI_117.png", right: "40px", (=> @showCode())
			@codeNodesButton.button.attr "title", 
				"Show/hide code that generated figures in this slide."
				
		# Close button
		new ImageButton @div, "UI_175.png", right: "10px", (=> @show false)
		
		@show false
		
	show: (show=true) ->
		disp = {display: if show then "inline" else "none"}
		@div.css disp
		@displayCallback show
		@displayed = show
		if show and not @gray
			# ZZZ make gray class
			doc = $(document)
			@gray = $ "<div>"
				class: "ui-widget-overlay"
				css:
					width: $(document.body).width()
					height: $(document).height()
					zIndex: 9
					pointerEvents: "none"
			$(document.body).append @gray
		if not show and @gray
			@gray.remove()
			@gray = null
			
	toggle: -> @show(not @displayed)
	
	append: (obj) -> @div.append obj
	
	# ZZZ create class for handling code nodes
	
	setCodeNodes: (nodes) ->
		@codeNodes = []
		@codeNodesButton.show nodes?
		return if not nodes?
		ids = nodes.split ","
		@codeNodes = ($.trim(id) for id in ids)
		@codeNodesButton.button.css(
			opacity: if @codeDisplayed() then 1 else 0.6
		)
				
	showCode: ->
		return if @codeNodes.length is 0
		show = not @codeDisplayed()
		$.event.trigger("showCode", {id: id, show: show}) for id in @codeNodes
#		$pz.event.showCode.trigger(id: id, show: show) for id in @codeNodes
		ace = $("#ace_editor_"+@codeNodes[0])
		# ZZZ dup code (above)
		@codeNodesButton.button.css(
			opacity: if @codeDisplayed() then 1 else 0.6
		)
		return if ace.parent().css("display") is "none"
		$(document.body).animate(scrollTop: ace.offset().top, 500)
		
	codeDisplayed: ->
		return false if @codeNodes.length is 0
		ace = $("#ace_editor_"+@codeNodes[0])
		return ace.parent().css("display") isnt "none"


class SlidesButton
	
	constructor: (@callback) ->
		return if not $ ".pz_slide"
		#parent = $(document.body)
		parent = $ "#blab_container"  # MVC - stemweblab
		@div = $ "<div>"
			css:
				position: "fixed"
				zIndex: 9  # 9
				bottom: "30px"
				right: 20
				#marginLeft: parent.width() + 20
				#marginLeft: parent.width() + 20
				height: "50px"
		@img = $ "<img>"
			src: "http://puzlet.org/puzlet/images/UI_302.png"
			height: 25
			css: {cursor: "pointer"}  #, opacity: 0.3}
			title: "Show/hide slides"
			click: => @callback()
		@div.append @img
		parent.append @div
		@show false
		@highlight false
		
	show: (show=true) -> 
		@img.css {display: if show then "inline" else "none"}
		
	highlight: (highlight=true) ->
		@img.css {opacity: if highlight then 1 else 0.3}


class Slide
	
	@lastCreated: null	# Static
	
	constructor: (@container, @ref, @section, @prev, @codeNodesCallback) ->
		source = $ "##{@ref}"
		@div = $ "<div>", html: source.html()
		@div.attr "class", "pz_slide_clone"
		@codeNodes = source.attr "codenodes"
		@links = []
		@index = 1 + 
			(if Slide.lastCreated then Slide.lastCreated.index else 0)
		@next = null
		@prev.next = this if @prev
		@container.append @div
		@show false
		Slide.lastCreated = this
				
	addLink: (link) -> @links.push link
	
	show: (show=true) -> 
		@div.css display: (if show then "inline" else "none")
		@highlightLinks show
		@codeNodesCallback @codeNodes
		
	highlightLinks: (highlight=true) ->
		for link in @links
			link.css background: (if highlight then "#F3F781" else "white")
		
	remove: -> @div.remove()


class NavButtons
	
	constructor: (@container, @goto) ->
		@index = new SlideIndex @container, 
			{bottom: "42px", right: "20px", width: "50px"}
		navPos = (right) -> bottom: "20px", right: right
		@prev = new ImageButton @container, "UI_36.png", navPos("50px"), 
			(=> @goto "prev")
		@next = new ImageButton @container, "UI_37.png", navPos("20px"), 
			(=> @goto "next")
		
	enable: (enablePrev, enableNext) ->
		@prev.enable enablePrev
		@next.enable enableNext
		
	setIndex: (idx, total) -> @index.set idx, total
	
	remove: ->
		@index.remove()
		@prev.remove()
		@next.remove()


class Button
	
	constructor: (@container, @label, css, @callback) ->
		@button = $ "<span>"
			text: @label
			css:
				position: "absolute"
				zIndex: 11
			click: => (@callback() if @enabled)
		@button.css css if css 
		@enable true
		@container.append @button
	
	enable: (enable) ->
		@button.css
			color: if enable then "black" else "#bbb"
			cursor: if enable then "pointer" else "default"
		@enabled = enable


class ImageButton
	# ZZZ create abstract class?  A lot of similarity with Button.
		
	constructor: (@container, @src, css, @callback) ->
		@button = $ "<img>"
			src: "http://puzlet.org/puzlet/images/#{@src}"
			height: 20
			width: 20
			css:
				position: "absolute"
				zIndex: 11
				cursor: "pointer"
			click: => @callback() #(@callback() if @enabled)
		@button.css css if css 
		@enable true
		@container.append @button
		
	show: (show=true) ->
		@button.css
			display: if show then "inline" else "none"
	
	enable: (enable) ->
		@button.css
			opacity: if enable then 1 else 0.3
			cursor: if enable then "pointer" else "default"
		@enabled = enable
		
	remove: -> @button.remove() 


class SlideIndex
	
	constructor: (@container, css) ->
		@div = $ "<div>"
			css:
				display: "block"
				position: "absolute"
				zIndex: 11
				textAlign: "center"
				fontSize: "8pt"
				color: "#aaa"
		@div.css css if css
		@container.append @div
		
	set: (@index, @of) -> @div.html "#{@index} of #{@of}"
	
	remove: -> @div.remove()

