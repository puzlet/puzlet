/* From https://github.com/Khan/KaTeX/tree/master/contrib/auto-render */

// Default page rendering
if (!window.console) window.console = {};
if (!window.console.log) window.console.log = function() {};
console.log("Render KaTeX");
renderMathInElement(
  document.getElementById("container"), {
    delimiters: [
      {left: "$$", right: "$$", display: true},
      {left: "\\[", right: "\\]", display: true},
      {left: "$", right: "$", display: false},
      {left: "\\(", right: "\\)", display: false}
    ]
  }
);
console.log("KaTeX done");