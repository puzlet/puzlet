// Uses auto-render in //puzlet.org/puzlet/js/vendor.js
// Default page rendering

if (!window.console) window.console = {};
if (!window.console.log) window.console.log = function() {};

(function() {
  
  var katexRendering = !window.$mathRendering || $mathRendering.indexOf("katex")!=-1;
  var mathjaxRendering = window.$mathRendering && $mathRendering.indexOf("mathjax")!=-1 
  var katexOnly = katexRendering && !mathjaxRendering;
  
  function katexProcessing() {
    console.log("Render KaTeX");
    
    //var mathjaxElementsToProcess = [];
  
    renderMathInElement(
      document.body, {
        delimiters: [
          {left: "$$", right: "$$", display: true},
          {left: "\\[", right: "\\]", display: true},
          {left: "$", right: "$", display: false},
          {left: "\\(", right: "\\)", display: false}
        ],
        ignoreClass: (katexOnly ? null : "mathjax-container"),
        error: function(e, fragment, data) {
          if (!(e instanceof katex.ParseError)) {
            throw e;
          }
          var errorText = "KaTeX auto-render: Failed to parse `" + data.data + "` with ";
          if (katexOnly) {
            console.error(errorText, e);
          } else {
            console.log(errorText, e);
            console.log("Marking to process with MathJax");
          }
          //var span = document.createElement("span");
          //span.className = "mathjax-container";
          //span.appendChild(document.createTextNode(data.rawData));
          //fragment.appendChild(span);
          fragment.appendChild(document.createTextNode(data.rawData));
          //mathjaxElementsToProcess.push(span);
        }
      }
    );
    
    console.log("KaTeX done");
  }
  
  function mathjaxProcessing() {
    window.mathjaxConfig = function() {
    
      console.log("MathJax configuration");
    
      window.MathJax.Hub.Config({
        jax: ["input/TeX", "output/HTML-CSS"],
        tex2jax: {inlineMath: [["$", "$"], ["\\(", "\\)"]], ignoreClass: "tex2jax_ignore", processEscapes: true},
        TeX: {equationNumbers: {autoNumber: "AMS"}},
        elements: [],  // No elements initially (default is KaTeX processing)
        showProcessingMessages: false,
        MathMenu: {showRenderer: true}  // Hide?
      });
    
      window.MathJax.HTML.Cookie.Set("menu", {renderer: "HTML-CSS"});
    
      // Not used
      var Hub = MathJax.Hub;
      function process(element, index, array) {
        Hub.Queue(["Typeset", Hub, element]);
        Hub.Queue(function() {
          // jQuery - MathJax bug fix - vertical lines.
          $(element).find('.math>span').css("border-left-color", "transparent");
        });
      }
    
      // Fix for chrome/mathjax vertical line at end of math.  Needs jQuery.
      MathJax.Hub.Register.StartupHook("End", function() {
        $('.math>span').css("border-left-color", "transparent");
        console.log("MathJax end processing");
      });
    
      //console.log("MathJax process elements", mathjaxElementsToProcess);
      //mathjaxElementsToProcess.forEach(process);
    };
  
    // MathJax configuration
    var s1 = document.createElement("script");
    s1.type = "text/x-mathjax-config";
    s1.text = "window.mathjaxConfig();";
    document.head.appendChild(s1);
  
    // MathJax.js
    var s2 = document.createElement("script");
    s2.type = "text/javascript";
    s2.src = "http://cdn.mathjax.org/mathjax/2.4-latest/MathJax.js?config=default";
    document.head.appendChild(s2);
    
  }
  
  if (katexRendering) {
    katexProcessing();
  }
  
  if (mathjaxRendering) {
    mathjaxProcessing();
  }
  
})();
