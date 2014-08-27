# TODO:
# tan, asin, acos, atan.
# Make predefinedCoffee a function?  Extract contents?
# Functional form for complex arg.

class BlabCoffee
	
	# This code is inserted into CoffeeScript nodes before compiling, unless #!vanilla directive at top of node.
	predefinedCoffee: """
		nm = numeric
		size = nm.size
		max = nm.max
		abs = nm.abs
		pow = nm.pow
		sqrt = nm.sqrt
		exp = nm.exp
		log = nm.log
		sin = nm.sin
		cos = nm.cos
		tan = nm.tan
		asin = nm.asin
		acos = nm.acos
		atan = nm.atan
		atan2 = nm.atan2
		ceil = nm.ceil
		floor = nm.floor
		round = nm.round
		rand = nm.rand
		complex = nm.complex
		conj = nm.conj
		linspace = nm.linspace
		print = nm.print
		plot = nm.plot
		plotSeries = nm.plotSeries
		eplot = nm.plot
		figure = nm.figure
		pi = Math.PI
		j = complex 0, 1
		print.clear()
		eplot.clear()
	"""
	
	# Operator arrays:
	# First column: method name for numericjs
	# Second column: __name for operator overload function.
	
	# Arithmetic operators
	basicOps: [
		["add", "add"]
		["sub", "subtract"]
		["mul", "multiply"]
		["div", "divide"]
	]
	
	# Modulus operator
	modOp: ["mod", "modulo"]
	
	# Equality/inequality operators
	eqOps: [
		["mod", "modulo"]
		["eq", "equals"]
		["lt", "lt"]
		["gt", "gt"]
		["leq", "leq"]
		["geq", "geq"]
	]
	
	# Assignment operators
	assignOps: ["addeq", "subeq", "muleq", "diveq", "modeq"]
	
	constructor: ->
		@ops = @basicOps.concat([@modOp]).concat(@eqOps)  # Scalar and Array ops.
		@predefinedCoffeeLines = @predefinedCoffee.split "\n"
		
	initializeMath: ->
		return if @mathInitialized?
		# This sets methods for Number and Array prototypes (and others).
		# Used only if a non-vanilla code node is compiled.
		window._$_ = PaperScript._$_
		window.$_ = PaperScript.$_
		new ScalarMath @ops
		new ArrayMath @ops, @assignOps
		new ComplexMath @basicOps
		new NumericFunctions
		new BlabPrinter
		new BlabPlotter
		new EvalBoxPlotter
		@mathInitialized = true
		
	compile: (code, bare=false) ->
		lf = "\n"
		codeLines = code.split lf
		firstLine = codeLines[0]
		vanilla = firstLine is "#!vanilla"
		unless vanilla
			@initializeMath()
			codeLines = @predefinedCoffeeLines.concat codeLines
			code = codeLines.join lf
		js = CoffeeScript.compile code, bare: bare
		js = PaperScript.compile js unless vanilla  # $blab.overloadOps no longer used.
		js
		

class TypeMath
	# Superclass
		
	constructor: (@proto) ->
	
	setMethod: (op) ->
		# Method for numericjs function.
		# e.g., Array.prototype.add = (y) -> numeric.add(this, y)
		@proto[op] = (y) -> numeric[op](this, y)
		
	setUnaryMethod: (op) ->
		# Array method for unary numericjs operator or function.
		# e.g., Array.prototype.neg = -> numeric.neg(this)
		@proto[op] = -> numeric[op](this)
	
	overloadOperator: (a, b) ->
		# Overload operator.  Set to operator method.
		# e.g., Array.prototype.__add = Array.prototype.add
		@proto["__"+b] = @proto[a]
	

class ScalarMath extends TypeMath
	
	constructor: (@ops) ->
		
		super Number.prototype
		
		# Regular operations
		for op in @ops
			[a, b] = op
			@setMethod a
			@overloadOperator a, b
			
		# Power
		@proto.pow = (p) -> Math.pow this, p
		
	setMethod: (op) ->
		# Method when first operand is scalar.
		# Need +this to convert to primitive value.
		# e.g., Number.protoype.add = (y) -> numeric.add(+this, y)
		@proto[op] = (y) -> numeric[op](+this, y)


class ArrayMath extends TypeMath
	
	constructor: (@ops, @assignOps) ->
		
		super Array.prototype
		
		# Size of 2D array
		@proto.size = -> [this.length, this[0].length]
		
		# Max value of array
		@proto.max = -> Math.max.apply null, this
		
		# Array builders
		numeric.zeros = (m, n) -> numeric.rep [m, n], 0
		numeric.ones = (m, n) -> numeric.rep [m, n], 1
		
		# Regular operations.
		for op in @ops
			[a, b] = op
			@setMethod a
			@overloadOperator a, b
			
		# Assignment operations.
		# Don't need to overload assignment operators.  Inferred from binary ops.
		@setMethod op for op in @assignOps
		
		# Dot product.  No operator overload for A.dot.
		@setMethod "dot"
		
		# Negation (unary).
		@setUnaryMethod "neg"
		@overloadOperator "neg", "negate"
		
		# Methods for other functions.
		@setUnaryMethod "clone"
		@setUnaryMethod "sum"
		
		# Transposes
		@proto.transpose = ->
			numeric.transpose this
		
		Object.defineProperty @proto, 'T', get: -> this.transpose()
		
		# Power - need this so don't get cyclic call.
		pow = numeric.pow
		@proto.pow = (p) -> pow this, p
		
		# Random numbers
		numeric.rand = (sz=null) ->
			if sz then numeric.random(sz) else Math.random()
			# ZZZ Also flatten?

class ComplexMath extends TypeMath
	
	constructor: (@ops) ->
		
		super numeric.T.prototype
		
		# Scalar to complex.
		numeric.complex = (x, y=0) -> new numeric.T(x, y)
		complex = numeric.complex
		
		# Size of complex array.
		@proto.size = -> [this.x.length, this.x[0].length]
		
		# Operators
		@defineOperators(op[0], op[1]) for op in @ops
	
		# Negation
		@proto.__negate = @proto.neg
		
		# Transposes
		Object.defineProperty @proto, 'T', get: -> this.transpose()
		Object.defineProperty @proto, 'H', get: -> this.transjugate()
		
		# Complex arg (angle)
		@proto.arg = ->
			x = this.x
			y = this.y
			numeric.atan2 y, x
		
		# Power.
		@proto.pow = (p) ->
			nm = numeric
			r = this.abs().x
			a = this.arg()
			pa = a.mul p
			complex(nm.cos(pa), nm.sin(pa)).mul(r.pow p)
		
		# Square root
		@proto.sqrt = -> this.pow 0.5
		
		# Natural logarthim
		@proto.log = ->
			r = this.abs().x
			a = this.arg()
			complex(numeric.log(r), a)
			
		#---Trig functions---
		
		# Constants for trig functions.
		j = complex 0, 1
		j2 = complex 0, 2
		negj = complex 0, -1
		# ZZZ create efficient method to rotate by +/-90 deg (for methods below)
		
		@proto.sin = ->
			e1 = (this.mul(j)).exp()
			e2 = (this.mul(negj)).exp()
			(e1.sub e2).div j2
			
		@proto.cos = ->
			e1 = (this.mul(j)).exp()
			e2 = (this.mul(negj)).exp()
			(e1.add e2).div 2
			
	defineOperators: (op, op1) ->
		# Redefine numeric.add (etc.) to check for scalar * numeric.T first.
		# Chain: 1+y (where y is a T) --> N._add --> N.add --> nm.add (redefined below) --> y.add 1 (T method)
		numericOld = {}  # Store old numeric methods here.
		@proto["__"+op1] = @proto[op]  # Operator overload
		numericOld[op] = numeric[op]  # Current method
		numeric[op] = (x, y) ->  # New method
			if typeof x is "number" and y instanceof numeric.T
				numeric.complex(x)[op] y  # Convert scalar to complex
			else
				numericOld[op] x, y  # Otherwise, just previous method.
	

class NumericFunctions
	
	overrideFcns: ["sqrt", "sin", "cos", "exp", "log"]
	
	constructor: ->
		
		# These numeric.f functions should call correct object methods:
		# pow, abs, sqrt, sin, cos, exp, log, atan2
		
		@override f for f in @overrideFcns
		
		#---Special handling---
		
		nm = numeric
		
		# Power
		npow = nm.pow
		nm.pow = (x, p) -> if x.pow? then x.pow(p) else npow(x, p)
		
		# Absolute value
		nabs = nm.abs
		nm.abs = (x) -> if x.abs? and x instanceof nm.T then x.abs().x else nabs(x)
		
		# atan2
		natan2 = nm.atan2
		nm.atan2 = (y, x) -> 
			if typeof(x) is "number" and typeof(y) is "number" then Math.atan2(y, x) else natan2(y, x)
	
	override: (name) ->
		f = numeric[name]
		numeric[name] = (x) ->
			if typeof(x) is "object" and x[name]?
				x[name]()
			else
			 	f(x)


class BlabPrinter
	
	constructor: ->
		
		nm = numeric
		
		id = "blab_print"
		
		nm.print = (x) ->
			container = $ "##{id}"
			unless container.length
				container = $ "<div>"
					id: id
				htmlOut = $ "#codeout_html"
				htmlOut.append container
			container.append("<pre>"+nm.prettyPrint(x)+"</pre>")
			
		nm.print.clear = ->
			container = $ "##{id}"
			container.empty() if container


class BlabPlotter
	
	constructor: ->
		
		numeric.htmlplot = (x, y, params={}) ->
			
			flot = $ "#flot"
			
			unless flot.length
				flot = $ "<div>"
					id: "flot"
					css: {width: "600px", height: "300px"}
				htmlOut = $ "#codeout_html"
				htmlOut.append flot
				
			params.series ?= {color: "#55f"}
			$.plot $("#flot"), [numeric.transpose([x, y])], params


class EvalBoxPlotter
	
	constructor: ->
		@clear()
		numeric.plot = (x, y, params={}) => @plot(x, y, params)
		numeric.plot.clear = => @clear()
		numeric.figure = (params={}) => @figure params
		numeric.plotSeries = (series, params={}) => @plotSeries(series, params)
		@figures = []
		@plotCount = 0
	
	clear: ->
		resource = $blab.evaluatingResource
		resource?.getEvalContainer()?.find(".eval_flot").remove()
		
	figure: (params={}) ->
		resource = $blab.evaluatingResource
		return unless resource
		flotId = "eval_plot_#{resource.url}_#{@plotCount}"
		
		@figures[flotId] = new Figure resource, flotId, params
		@plotCount++
		flotId  # ZZZ need to replace this line in coffee eval box
	
	doPlot: (params, plotFcn) ->
		flotId = params.fig ? @figure params
		return null unless flotId
		fig = @figures[flotId]
		return null unless fig
		plotFcn fig
		if params.fig then null else flotId
	
	plot: (x, y, params={}) ->
		@doPlot params, (fig) -> fig.plot(x, y)  # no support yet for params here
		
	plotSeries: (series, params={}) ->
		@doPlot params, (fig) -> fig.plotSeries(series)  # no support yet for params here


class Figure
	
	constructor: (@resource, @flotId, @params) ->
		
		@container = @resource.getEvalContainer()
		return unless @container?.length
		
		# Plot container (eval box)
		@w = @container[0].offsetWidth
		
		@flot = $ "<div>",
			id: @flotId
			class: "eval_flot"
			css:
				position: "absolute"
				top: "0px"
				width: (@params.width ? @w-50)+"px"
				height: (@params.height ? 150)+"px"
				margin: "0px"
				marginLeft: "30px"
				marginTop: "20px"
				#background: "white"
				zIndex: 1  # ZZZ needed?
			
		@container.append @flot
		@flot.hide()
		@positioned = false
		setTimeout (=> @setPos()), 10	# ZZZ better way them timeout?	e.g., after blab eval?
		
	setPos: ->
		p = @resource.compiler.findStr @flotId  # ZZZ finds *last* one
		return unless p
		@flot.css top: "#{p*22}px"
		@flot.show()  # Delay showing div until set position
		@axesLabels?.position()
		@positioned = true
		
	plot: (x, y) ->
		
		return unless @flot?
		
		# ZZZ currently all params must be set at figure creation
		# ZZZ later, copy params fields to @params
		#return unless y?.length
		#@params.series ?= {color: "#55f"}
		if y?.length and y[0].length?
			nLines = y.length
			d = []
			for line in y
				v = numeric.transpose([x, line])
				d.push v
		else
			d = [numeric.transpose([x, y])]
		@plotSeries d
		
	plotSeries: (series) ->
		# ZZZ dup code
		return unless @flot?
		@params.series ?= {color: "#55f"}
		@flot.show() unless @positioned
		$.plot @flot, series, @params
		@flot.hide() unless @positioned
		@axesLabels = new AxesLabels @flot, @params
		@axesLabels.position() if @positioned
		


class AxesLabels
	
	constructor: (@container, @params) ->
		@xaxisLabel = @appendLabel @params.xlabel, "xaxisLabel" if @params.xlabel
		@yaxisLabel = @appendLabel @params.ylabel, "yaxisLabel" if @params.ylabel
			
	appendLabel: (txt, className) ->
		label = $ "<div>", text: txt
		label.addClass "axisLabel"
		label.addClass className
		@container.append label
		label
	
	position: ->
		@xaxisLabel?.css
			marginLeft: (-@xaxisLabel.width()/2 + 10) + "px"  # width of ylabels?
			marginBottom: "-20px"
			
		@yaxisLabel?.css
			marginLeft: "-27px"
			marginTop: (@yaxisLabel.width()/2 - 10) + "px"


### Not used - to obsolete

complexMatrices: ->
	
	Array.prototype.complexParts = ->
		A = this
		[m, n] = size A
		vParts = (v) -> [(a.x for a in v), (a.y for a in v)]
		if not n
			# Vector
			[real, imag] = vParts A
		else
			# Matrix
			real = new Array m
			imag = new Array m
			[real[m], imag[m]] = vParts(row) for row, m in A
		[real, imag]
	
	# These could be made more efficient.
	Array.prototype.real = -> this.complexParts()[0]
	Array.prototype.imag = -> this.complexParts()[1]
	
	#Array.prototype.isComplex = ->
	#	A = this
	#	[m, n] = size A

manualOverloadExamples: ->
	# Not currently used - using numericjs instead.
	
	Number.prototype.__add = (y) ->
		# ZZZ is this inefficient for scaler x+y?
		if typeof y is "number"
			return this + y
		else if y instanceof Array
			return (this + yn for yn in y)
		else
			undefined

	Array.prototype.__add = (y) ->
		if typeof y is "number"
			return (x + y for x in this)
		else if y instanceof Array
			return (x + y[n] for x, n in this)
		else
			undefined
	
###
