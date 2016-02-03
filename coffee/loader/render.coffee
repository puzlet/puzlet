# Temporary rendering functions.  Will be moved into own repos as separate components.

$blab?.resources?.on "ready", ->
    new MathJaxProcessor
    new Notes

class MathJaxProcessor
  
  source: "http://cdn.mathjax.org/mathjax/2.4-latest/MathJax.js?config=default"
# source: "http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=default"
    # default, TeX-AMS-MML_SVG, TeX-AMS-MML_HTMLorMML
  #outputSelector: ".code_node_html_output"
  mode: "HTML-CSS"  # HTML-CSS, SVG, or NativeMML
  
  constructor: ->  # ZZZ param via mode?
  
    #return # DEBUG
    
    container = $("#container")
    hasBodyContainer = container.length and container.parent().is("body") or container.parent().attr("id") is "outer-container" 
    @outputId = if hasBodyContainer then "container" else "blab_container"
    
#   @outputId = "codeout_html"
    
    #MathJaxProcessor?.mode = "SVG"
    
    #@mode = "SVG"
    # return if $blab.mathjaxConfig already exists?
    
    $blab.mathjaxConfig = =>
      $.event.trigger "mathjaxPreConfig"
      window.MathJax.Hub.Config
        jax: ["input/TeX", "output/#{@mode}"]
        tex2jax: {inlineMath: [["$", "$"], ["\\(", "\\)"]], ignoreClass: "tex2jax_ignore", processEscapes: true}
        TeX: {equationNumbers: {autoNumber: "AMS"}}
        elements: [@outputId, "blab_refs"]
        showProcessingMessages: false
        #"HTML-CSS": {scale: 100}
        MathMenu:
          showRenderer: true
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
    #queue (->
    #  $.event.trigger "mathjaxProcessed"
    #)
    configElements = => Hub.config.elements = [@id]
    queue configElements


# Mouseovers notes
class Notes
  
  constructor: ->
    return unless $(document).tooltip?
    @initTooltip()
    @processText((t) => @init t)
    $(document).on "mathjaxPreConfig", =>
      #MathJax.Hub.signal.Interest (message) ->
      # console.log "Hub", message
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
