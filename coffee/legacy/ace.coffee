Ace = {}

class Ace.Node
	
	constructor: (@container, @resource) ->
		@getSpec()
		@create()
		@renderTId = null
		
	# Specialize in subclass
	getSpec: ->
		return unless @resource
		@filename = @resource.url
		@lang = Ace.Languages.langName @resource.fileExt
		@spec =
			container: @container
			filename: @filename
			lang: @lang
			
	create: -> # Override in subclass
		
	code: -> @editor.code()
	
	setCode: (triggerChange=true) ->
		#setEditorView = false
		clearTimeout @renderTId if @renderTId
		@editor.set @resource.content, triggerChange #, setEditorView
		@renderTId = setTimeout (=> @editor.customRenderer.render()), 1000


class Ace.EditorNode extends Ace.Node
	
	getSpec: ->
		super()
		return unless @resource
		@spec.code = @resource.content
		@getAttributes()
		#console.log "start/end", @viewPort, @startLine, @endLine
		@spec.startLine = @startLine
		@spec.endLine = @endLine
		@spec.viewPort = @viewPort
		@spec.update = (code) => @resource.update?(code)  # Updates resource code
		
	create: ->
		Editor = Ace.Languages.get(@spec.lang).Editor ? Ace.Editor
		@editor = new Editor @spec
		@editor.onChange =>
			@resource.setFromEditor @editor
			@resource.edited = true  # ZZZ put into setContent?
			$.event.trigger "codeNodeChanged"
		
	getAttributes: ->
		lines = @resource.content.split("\n")  # ZZZ this will not work for EvalNode
		numLines = lines.length
		data = (name) => @container.data name
		@startMatch = data "start-match"
		@endMatch = data "end-match"
		@startLine = @match(lines, @startMatch) ? (data("start-line") ? 1)
		@endLine = @match(lines, @endMatch) ? (data("end-line") ? numLines)
		@viewPort = @startLine>1 or @endLine<numLines
			
	match: (lines, regex) ->
		return null unless lines?.length and regex
		for line, idx in lines
			match = line.match regex
			return idx+1 if match
		null
			


class Ace.EvalNode extends Ace.Node
	
	constructor: (@container, @resource, @fileNode) ->
		super @container, @resource
	
	getSpec: ->
		super()
		@spec.startLine = @fileNode.spec.startLine
		@spec.endLine = @fileNode.spec.endLine
		@spec.viewPort = @fileNode.spec.viewPort
	
	create: ->
		
		# Initially, support only CoffeeScript eval.
		if @lang isnt "coffee"
			console.log "<div data-eval='#{@filename}'>: must be CoffeeScript."
			return
		
		@editor = new CoffeeEval @spec
		@setCode()
		# ZZZ handle via resource event? (need resource listener)
		$(document).on "compiledCoffeeScript", (ev, data) =>
			@setCode() if data.url is @filename
			
	setCode: ->
		@editor.set @resource.resultStr
	


class Ace.Editor
	
	# ZZZ methods to get resource attrs?
	# ZZZ rename container?
	
	idPrefix: "ace_editor_"
	@count: 0  # Counts number of editor instances.
	
	constructor: (@spec) ->
		
		@filename = @spec.filename
		@lang = @spec.lang
		Ace.Editor.count++
		@id = @idPrefix + @filename + ("_#{@spec.startLine}_#{@spec.endLine}") + "_#{Ace.Editor.count}"
		@fixedNumLines = if @spec.viewPort then @spec.endLine - @spec.startLine + 1 else null
		
		@initContainer()
		
		@editor = ace.edit @id
		
		# Hack to deal with CORS issue loading Ace workers.
		#host = window.location.hostname
		#useWorkers = host is "localhost" or host is "puzlet.org"
		#@session().setUseWorker false unless useWorkers
		
		@initMode()
		@initRenderer()
		@initFont()
		@editor.$blockScrolling = Infinity
		
		@set @spec.code
		@setEditable()
		
		@initChangeListeners()
		@keyboardShortcuts()
		@onSwipe => @run() #@spec.update(@code())
		
		@customRenderer = new Ace.CustomRenderer this, (=> @setViewPort())
		@setViewPort()
	
	initContainer: ->
		@container = @spec.container
		@container.addClass "code_node_container"
		@container.addClass "tex2jax_ignore"
		@outer = $ "<div>", class: "code_node_editor_container"  # ZZZ rename?
		@editorContainer = $ "<div>",
			class: "code_node_editor"
			id: @id
			"data-lang": "#{@lang}"
		@outer.append @editorContainer
		@container.append @outer
	
	onSwipe: (callback) ->
		# Right swipe
		down = null
		pos = (evt) ->
			t = evt.touches[0]
			{x: t.clientX, y: t.clientY}
		start = (evt) -> down = pos(evt)
		move = (evt) ->
			return unless down
			up = pos(evt)
			d = {x: up.x-down.x, y: up.y-down.y}
			callback?() if Math.abs(d.x)>Math.abs(d.y) and d.x>0
			down = null
		listener = (e, f) => @editorContainer[0].addEventListener(e, f, false)
		listener "touchstart", start
		listener "touchmove", move
	
	initMode: ->
		@editor.setTheme "ace/theme/textmate"
		mode = Ace.Languages.mode(@lang) if @lang
		@session().setMode mode if mode
	
	
	initRenderer: ->
		
		@renderer = @editor.renderer
		
		# Initially no scroll bars
		@renderer.scrollBar.setWidth = (width) ->
			# width and element are properties of renderer
			width = this.width or 15 unless width?
			$(this.element).css("width", width + "px")
		
		@renderer.scrollBar.setWidth 0
		@renderer.scroller.style.overflowX = "hidden"
		#@renderer.$gutter.style.minWidth = "32px";
		#@renderer.$gutter.style.paddingLeft = "5px";
		#@renderer.$gutter.style.paddingRight = "5px";
		
		# If Ace changes line height, update height of editor box.
		# This is always called after body loaded because Ace uses polling approach for character size change.
		@renderer.$textLayer.addEventListener "changeCharacterSize", => @setHeight()
		
		# Note: ace.js had to be edited directly to handle this. See comment "MVC" in ace.js.
		@renderer.$gutterLayer.setShowLineNumbers = (show, start=1) ->
			this.showLineNumbers = show
			this.lineNumberStart = start
			
		@renderer.$gutterLayer.setShowLineNumbers true, 1  # Default - line numbers enabled
		#@renderer.$gutterLayer.setShowLineNumbers false, 1  # Initially no line numbers
		@editor.setShowFoldWidgets false
	
	
	initFont: ->
		
		# Code node editor is 720px wide
		# Left margin (line numbers + code margin) is ~3 characters
		# Menlo/DejaVu 11pt or Consolas 12pt char width is 9px
		# 77 characters per line (but cutoff at ~75 if v.scrollbar margin)
		# Total chars per editor width: 77+3=80 = 720/9
		
		# To experiment with fonts in puzlet page, use coffee node:
		# puzletInit.register(=> $(".code_node_editor").css css)
		
		# We found that using font-face fonts from google meant that MathJax needed 90% scaling.
		
		@editorContainer.addClass "pz_ace_editor"
		# Fonts do not work via CSS class.
		css =
			fontFamily: "Consolas, Menlo, DejaVu Sans Mono, Monaco, monospace" 
			fontSize: "11pt" 
			lineHeight: "150%"
		char = $ "<span>",
			css: css
			html: "m"
		$("body").append char
		@charWidth = char.width()
		char.remove()
		@narrowFont = @charWidth<9
		css.fontSize = "12pt" if @narrowFont  # For Consolas
		@editorContainer.css css
	
	
	setViewPort: ->
		return unless @spec.viewPort
		startLine = @spec.startLine
		endLine = @spec.endLine
		height = endLine - startLine + 1
		
		@setHeight height
		if startLine>1
			#console.log "startLine/endLine", @id, startLine, endLine
			@editor.gotoLine startLine-1
			@editor.scrollToLine startLine-1
		lines = @code().split("\n")  # ZZZ dup code
		numLines = lines.length
		for line in [1..numLines]
			@session().addGutterDecoration(line-1, "ace_light_line_numbers") if line<startLine or line>endLine
	
	
	setHeight: (numLines=null)->
		return if not @editor
		lineHeight = @renderer.lineHeight
		numLines ?= @fixedNumLines
		unless numLines
			lines = @code().split("\n")
			numLines = lines.length
			if numLines<20
				lengths = (l.length for l in lines)
				max = Math.max.apply(Math, lengths)
				numLines++ if max>75
			else
				numLines++
		return if @numLines is numLines and @lineHeight is lineHeight
		
		@numLines = numLines
		@lineHeight = lineHeight
		heightStr = lineHeight * (if numLines>0 then numLines else 1) + "px"
		@editorContainer.css("height", heightStr)
		@outer.css("height", heightStr) # ZZZ Is this the best way?
		@editor.resize()
	
	
	focus: -> 
		@editor.focus()  # ZZZ How is this different from base class focus?
	
	
	session: ->
		if @editor then @editor.getSession() else null
	
	
	code: ->
		@session().getValue()
	
	
	set: (code, triggerChange=true, setEditorView=true) ->
		@enableChangeAction = false unless triggerChange
		# ZZZ or setCode
		return unless @editor
		return unless code
		@session().setValue code
		if setEditorView
			if @spec.viewPort
				@setViewPort()
			else
				@setHeight()
		@enableChangeAction = true
	
	
	show: (show) ->
		@outer.css("display", if show then "" else "none")
	
	
	showCode: (show) ->
		@editor.show show
		@editor.resize() if show
	
	
	setEditable: (editable=true) ->
		@isEditable = editable
		@editor.setReadOnly (not editable)
		@editor.setHighlightActiveLine false
	
	
	initChangeListeners: ->
		@enableChangeAction = true
		changeAction = =>
			@setHeight()  # Resize if code changed.
			code = @code()
			#@spec.change? this
			listener code for listener in @changeListeners
		@session().on "change", =>
			changeAction() if @enableChangeAction
		@changeListeners = []
	
	
	onChange: (f) ->
		@changeListeners.push f
	
	
	run: ->
		@spec.update(@code())
		$.event.trigger "runCode"
	
	keyboardShortcuts: ->
		command = (o) => @editor.commands.addCommand o
		command
			name: "run"
			bindKey: 
				win: "Shift-Return"
				mac: "Shift-Return"
				sender: "editor"
			exec: (env, args, request) => @run()
		command
			name: "save"
			bindKey:
				win: "Ctrl-s"
				mac: "Ctrl-s"
				sender: "editor"
			exec: (env, args, request) =>
				#@spec.update(@code())
				$.event.trigger "saveGitHub"
	


class CoffeeEditor extends Ace.Editor
	
	constructor: (@spec) ->
		super @spec
		#@setEditable()


class CoffeeEval extends Ace.Editor
	
	idPrefix: "ace_eval_"
	
	constructor: (@spec) ->
		super @spec
		@container.css
			position: "relative"  # So that plots work inside div
			border: "1px dashed black"
		@editorContainer.css background: "white" # Doesn't work via CSS style sheet.
		@renderer.setShowGutter false


class Ace.Languages
	
	@list:
		html: {ext: "html", mode: "html"}
		css: {ext: "css", mode: "css"}
		javascript: {ext: "js", mode: "javascript"}
		coffee: {ext: "coffee", mode: "coffee", Editor: CoffeeEditor}
		json: {ext: "json", mode: "javascript"}
		python: {ext: "py", mode: "python"}
		octave: {ext: "m", mode: "matlab"}
		latex: {ext: "tex", mode: "latex"}
	
	@get: (lang) -> Ace.Languages.list[lang]
	
	@mode: (lang) -> "ace/mode/"+(Ace.Languages.get(lang).mode)
	
	@langName: (ext) ->
		return name for name, language of Ace.Languages.list when language.ext is ext


Ace.path = "http://ajaxorg.github.io/ace-builds/src-min"
#Ace.path = "http://ajaxorg.github.io/ace-builds/src-min-noconflict"
#Ace.path = "/puzlet/js/ace5"  # ace5
#Ace.path = "http://static.puzlet.com/ace5"
#Ace.path = "http://static.puzlet.com/ace4"
#Ace.path = "//cdnjs.cloudflare.com/ajax/libs/ace/1.1.3"

class Ace.Resources
	
	main: [
		{url: "#{Ace.path}/ace.js"}
	]
	
	modes: [
		{url: "#{Ace.path}/mode-html.js"}
		{url: "#{Ace.path}/mode-css.js"}
		{url: "#{Ace.path}/mode-javascript.js"}
		{url: "#{Ace.path}/mode-coffee.js"}
		{url: "#{Ace.path}/mode-python.js"}
		{url: "#{Ace.path}/mode-matlab.js"}
		{url: "#{Ace.path}/mode-latex.js"}
	]
	
	styles: [
		{url: "/puzlet/css/ace.css"}  # Must be loaded after ace.js
	]
	
	constructor: (load, loaded) ->
		load @main, => load @modes, => load @styles, =>
			@customStyles()
			#setTimeout (=> @customStyles()), 5000
			loaded?()
	
	customStyles: ->
		# These styles don't work if added via ace.css.
		custom = $ "<style>",
			type: "text/css"
			id: "puzlet_ace_custom_styles"
			html: """
			.ace-tm {
				background: #f4f4f4;;
			}
			.ace-tm .ace_gutter {
				color: #aaa;
				background: #f8f8f8;
			}
			.ace_gutter-cell {
				padding-left: 15px;
				background: #eee;
			}
			.ace-tm .ace_print_margin {
				background: #f0f0f0;
			}
			"""
			
		head = document.getElementsByTagName('head')[0]  # Doesn't work with jQuery.
		head.appendChild custom[0]


#--- Ace custom rendering: comments and function links ---# 

class Ace.CustomRenderer
	
	@tempIdx: 0
	
	constructor: (@node, @callback1, @callback) ->
		
		@editorContainer = @node.editorContainer
		@editor = @node.editor
		@renderer = @node.renderer
		@isEditable = @node.isEditable
		
		@customRendering()
	
	customRendering: ->
		
		@linkSelected = false
		@comments = []
		@functions = []
		
		#@editor.setShowFoldWidgets false
		#@renderer.$gutterLayer.setShowLineNumbers true, 1
		
		@inFocus = false
		
		# Override onFocus method.
		onFocus = @editor.onFocus  # Current onFocus method.
		@editor.onFocus = =>
			@restoreCode()
			# ZZZ issue here?
			onFocus.call @editor
			@renderer.showCursor() if @isEditable
			@renderer.hideCursor() unless @isEditable
			@editor.setHighlightActiveLine true #if source.isEditable
			@inFocus = true
		
		onBlur = @editor.onBlur  # Current onBlur method.
		@editor.onBlur = =>
			@renderer.hideCursor()
			@editor.setHighlightActiveLine false
			@render()
			@inFocus = false
			#onBlur.call @editor  # Why is this omitted?
		
		# Comment link navigation etc.
		@editor.on "mouseup", (aceEvent) => @mouseUpHandler()
		
		# ZZZ temporary hack to render function links
		#@registerLinks()
		
		#commentNodes = @editorContainer.find ".ace_comment"
		#@commentTest commentNodes
		
		$(document).on "mathjaxPreConfig", =>
			@callback1?()
			window.MathJax.Hub.Register.StartupHook "MathMenu Ready", =>
				@render()
				@callback?()
		
		#@render()
		
		
	render: ->
		
		#console.log "render", @node.id
		
		return unless window.MathJax
		return unless $blab.codeDecoration
		
		commentNodes = @editorContainer.find ".ace_comment"
		linkCallback = (target) => @linkSelected = target
		@comments = (new CodeNodeComment($(node), linkCallback) for node in commentNodes)
		comment.render() for comment in @comments
		
		# Identifiers/functions test.
		identifiers = @editorContainer.find ".ace_identifier"
		@functions = (new CodeNodeFunction($(i), l, linkCallback) for i in identifiers when l = Ace.Identifiers.link($(i).text()))
		f.render() for f in @functions
		# Also should look for class="ace_entity ace_name ace_function"
			
	
	restoreCode: ->
		comment.restore() for comment in @comments
		f.restore() for f in @functions
		
		
	mouseUpHandler: ->
		# Comment link navigation.
		return unless @linkSelected
		href = @linkSelected.attr "href"
		target = @linkSelected.attr "target"
		if target is "_self"
			$(document.body).animate {scrollTop: $(href).offset().top}, 1000
		else
			window.open href, target ? "_blank"
		@linkSelected = false
		@editor.blur()


class Ace.Identifiers
	
	@links: {}
	
	@registerLinks: (links) ->
		for identifier, link of links
			Ace.Identifiers.links[identifier] = link
	
	@link: (name) ->
		Ace.Identifiers.links[name]


class CodeNodeComment
	
	# ZZZ: potential bug - dangerous if render twice in row without restore?
	
	constructor: (@node, @linkCallback) ->
		
	render: ->
		@originalText = @node.text()
		#wikyOut = Wiky.toHtml(comment)
		@replaceDiv()
		@mathJax()
		@processLinks()
		
	#saveOriginal: ->
		# ZZZ shouldn't need to save in DOM?
	#	c = "pz_original_comment"
	#	@original = @node.siblings ".#{c}"
	#	@original?.remove()
	#	@original = $ "<div>"  # <span> ?
	#		class: c
	#		css: display: "none"
	#		text: @originalText
	#	@original.insertAfter @node
		
	replaceDiv: ->
		pattern = String.fromCharCode(160)
		re = new RegExp(pattern, "g")
		comment = @originalText.replace(re, " ")
		@node.empty()
		content = $ "<div>", css: display: "inline-block"
		content.append comment
		@node.append content
		
	mathJax: ->
		return unless node = @node[0]
		MathJax.Hub.Queue(["PreProcess", MathJax.Hub, node])
		MathJax.Hub.Queue(["Process", MathJax.Hub, node])
	
	processLinks: ->
		links = @node.find "a"
		return unless links.length
		for link in links
			$(link).mousedown (evt) => @linkCallback $(evt.target)
			
	restore: ->
		if @originalText  # ZZZ call @original ?
			@node.empty()
			@node.text @originalText


class CodeNodeFunction
	# Very similar to above.  Have base class?
	
	constructor: (@node, @link, @linkCallback) ->
		
	render: ->
		@originalText = @node.text()
		#wikyOut = Wiky.toHtml(comment)
		@replaceDiv()
		@processLinks()
		
	replaceDiv: ->
		#pattern = String.fromCharCode(160)  # needed?
		#re = new RegExp(pattern, "g")
		#txt = @originalText.replace(re, " ")
		txt = @originalText
		link = $ "<a>",
			href: @link.href
			target: @link.target
			text: txt
		@node.empty()
		content = $ "<div>", css: display: "inline-block"
		content.append link
		@node.append content
		
	mathJax: ->
		return unless node = @node[0]
		MathJax.Hub.Queue(["PreProcess", MathJax.Hub, node])
		MathJax.Hub.Queue(["Process", MathJax.Hub, node])
	
	processLinks: ->
		links = @node.find "a"
		return unless links.length
		for link in links
			$(link).mousedown (evt) => @linkCallback $(evt.target)
			
	restore: ->
		if @originalText  # ZZZ call @original ?
			@node.empty()
			@node.text @originalText

