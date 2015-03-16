// Generated by CoffeeScript 1.3.3
(function() {
  var Blab, CoffeeResource, CssResourceInline, CssResourceLinked, EditorContainer, EvalContainer, HtmlResource, JsResourceInline, JsResourceLinked, JsonResource, Loader, Resource, ResourceContainers, ResourceFactory, ResourceInline, ResourceLocation, Resources,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  console.log("LOADER");

  Blab = (function() {

    function Blab() {
      var ready, render;
      this.publicInterface();
      this.location = new ResourceLocation;
      render = function() {};
      ready = function() {};
      this.loader = new Loader(this.location, render, ready);
    }

    Blab.prototype.publicInterface = function() {
      window.$pz = {};
      window.$blab = {};
      if (window.console == null) {
        window.console = {};
      }
      if (window.console.log == null) {
        window.console.log = (function() {});
      }
      return $blab.codeDecoration = true;
    };

    return Blab;

  })();

  Loader = (function() {
    /*
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
    */

    Loader.prototype.coreResources = [
      {
        url: "http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js",
        "var": "jQuery"
      }, {
        url: "/puzlet/puzlet/js/google_analytics.js"
      }, {
        url: "http://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/themes/smoothness/jquery-ui.css",
        "var": "jQuery"
      }, {
        url: "/puzlet/puzlet/js/coffeescript.js"
      }, {
        url: "/puzlet/coffeescript/compiler.js"
      }, {
        url: "/puzlet/puzlet/js/wiky.js",
        "var": "Wiky"
      }
    ];

    Loader.prototype.resourcesList = {
      url: "resources.json"
    };

    Loader.prototype.resourcesList2 = {
      url: "resources.coffee"
    };

    Loader.prototype.htmlResources = window.blabBasic ? [
      {
        url: ""
      }
    ] : [
      {
        url: "/puzlet/puzlet/css/coffeelab.css"
      }
    ];

    Loader.prototype.scriptResources = [
      {
        url: "/puzlet/puzlet/js/acorn.js"
      }, {
        url: "/puzlet/puzlet/js/numeric-1.2.6.js"
      }, {
        url: "/puzlet/puzlet/js/jquery.flot.min.js"
      }, {
        url: "/puzlet/puzlet/js/compile.js"
      }, {
        url: "/puzlet/puzlet/js/jquery.cookie.js"
      }, {
        url: "http://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/jquery-ui.min.js",
        "var": "jQuery.ui"
      }
    ];

    function Loader(blabLocation, render, done) {
      var _this = this;
      this.blabLocation = blabLocation;
      this.render = render;
      this.done = done;
      this.resources = new Resources(this.blabLocation);
      this.publicInterface();
      this.loadCoreResources(function() {
        return _this.loadResourceList2(function() {
          return _this.loadHtmlCss(function() {
            return _this.loadScripts(function() {
              return _this.done();
            });
          });
        });
      });
    }

    Loader.prototype.loadCoreResources = function(callback) {
      var _this = this;
      this.resources.add(this.coreResources);
      return this.resources.loadUnloaded(function() {
        return typeof callback === "function" ? callback() : void 0;
      });
    };

    Loader.prototype.loadGitHub = function(callback) {
      this.github = new GitHub(this.resources);
      return this.github.loadGist(callback);
    };

    Loader.prototype.loadResourceList = function(callback) {
      var list,
        _this = this;
      list = this.resources.add(this.resourcesList);
      return this.resources.loadUnloaded(function() {
        var listResources, r, spec, _i, _len;
        _this.resources.add(_this.htmlResources);
        _this.resources.add(_this.scriptResources);
        listResources = JSON.parse(list.content);
        for (_i = 0, _len = listResources.length; _i < _len; _i++) {
          r = listResources[_i];
          spec = typeof r === "string" ? {
            url: r
          } : r;
          _this.resources.add(spec);
        }
        return typeof callback === "function" ? callback() : void 0;
      });
    };

    Loader.prototype.loadResourceList2 = function(callback) {
      var res,
        _this = this;
      res = this.resources.add({
        url: this.resourcesList2.url,
        doEval: true
      });
      return this.resources.loadUnloaded(function() {
        var result, _i, _len, _ref;
        res.compile();
        _this.resources.add(_this.htmlResources);
        _this.resources.add(_this.scriptResources);
        _ref = res.resultArray;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          result = _ref[_i];
          if (typeof result === "string" && result.length) {
            _this.resources.add({
              url: result
            });
          }
        }
        return typeof callback === "function" ? callback() : void 0;
      });
    };

    Loader.prototype.loadHtmlCss = function(callback) {
      var _this = this;
      return this.resources.load(["html", "css"], function() {
        var html, _i, _len, _ref;
        _ref = _this.resources.select("html");
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          html = _ref[_i];
          _this.render(html.content);
        }
        return typeof callback === "function" ? callback() : void 0;
      });
    };

    Loader.prototype.loadScripts = function(callback) {
      var _this = this;
      return this.resources.load(["json", "js", "coffee", "py", "m", "svg", "txt"], function() {
        _this.compileCoffee(function(coffee) {
          return !coffee.hasEval() && !coffee.spec.orig.doEval;
        });
        return typeof callback === "function" ? callback() : void 0;
      });
    };

    Loader.prototype.loadAce = function(callback) {
      var load,
        _this = this;
      load = function(resources, callback) {
        _this.resources.add(resources);
        return _this.resources.load(["js", "css"], function() {
          return typeof callback === "function" ? callback() : void 0;
        });
      };
      return new Ace.Resources(load, function() {
        _this.resources.render();
        _this.compileCoffee(function(coffee) {
          return coffee.hasEval();
        });
        return typeof callback === "function" ? callback() : void 0;
      });
    };

    Loader.prototype.compileCoffee = function(coffeeFilter) {
      var coffee, filter, _i, _len, _ref, _results;
      filter = function(resource) {
        return resource.isType("coffee") && coffeeFilter(resource);
      };
      _ref = this.resources.select(filter);
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        coffee = _ref[_i];
        _results.push(coffee.compile());
      }
      return _results;
    };

    Loader.prototype.publicInterface = function() {
      var _this = this;
      $blab.resources = this.resources;
      $blab.loadJSON = function(url, callback) {
        return _this.resources.loadJSON(url, callback);
      };
      return $blab.resource = function(id) {
        return _this.resources.getContent(id);
      };
    };

    return Loader;

  })();

  ResourceLocation = (function() {

    function ResourceLocation(url) {
      var branch, f, hasPath, hostParts, match, pathIdx, repoIdx, s, specOwner, _ref;
      this.url = url != null ? url : window.location.href;
      this.a = document.createElement("a");
      this.a.href = this.url;
      this.host = this.a.hostname;
      this.path = this.a.pathname;
      this.search = this.a.search;
      this.getGistId();
      hostParts = this.host.split(".");
      this.pathParts = this.path ? this.path.split("/") : [];
      hasPath = this.pathParts.length;
      specOwner = hasPath && this.pathParts[0] === "";
      this.isLocalHost = this.host === "localhost";
      this.isPuzlet = this.host === "puzlet.org";
      this.isGitHub = hostParts.length === 3 && hostParts[1] === "github" && hostParts[2] === "io";
      this.isGitHubApi = this.host === "api.github.com" && this.pathParts.length === 6 && this.pathParts[1] === "repos" && this.pathParts[4] === "contents";
      this.owner = (function() {
        switch (false) {
          case !(this.isLocalHost && specOwner):
            return this.pathParts[1];
          case !this.isPuzlet:
            return "puzlet";
          case !this.isGitHub:
            if (specOwner) {
              return this.pathParts[1];
            } else {
              return hostParts[0];
            }
            break;
          case !(this.isGitHubApi && hasPath):
            return this.pathParts[2];
          default:
            return null;
        }
      }).call(this);
      this.repo = null;
      this.subf = null;
      if (hasPath) {
        repoIdx = (function() {
          switch (false) {
            case !this.isLocalHost:
              if (specOwner) {
                return 2;
              } else {
                return 1;
              }
              break;
            case !this.isPuzlet:
              return 1;
            case !this.isGitHub:
              if (specOwner) {
                return 2;
              } else {
                return 1;
              }
              break;
            case !this.isGitHubApi:
              return 3;
            default:
              return null;
          }
        }).call(this);
        this.repoIdx = repoIdx;
        if (repoIdx) {
          this.repo = this.pathParts[repoIdx];
          pathIdx = repoIdx + (this.isGitHubApi ? 2 : 1);
          this.subf = this.pathParts.slice(pathIdx, -1).join("/");
        }
      }
      match = hasPath ? this.path.match(/\.[0-9a-z]+$/i) : null;
      this.fileExt = (match != null ? match.length : void 0) ? match[0].slice(1) : null;
      this.file = this.fileExt ? specOwner ? this.pathParts.slice(-1)[0] : this.pathParts.slice(-1)[0] : null;
      this.inBlab = this.file && this.url.indexOf("/") === -1;
      if (this.gistId) {
        f = (_ref = this.file) != null ? _ref.split(".") : void 0;
        this.source = ("https://gist.github.com/" + this.gistId) + (this.file ? "#file-" + f[0] + "-" + f[1] : "");
      } else if (this.owner && this.repo) {
        s = this.subf ? "/" + this.subf : "";
        branch = "gh-pages";
        this.source = ("https://github.com/" + this.owner + "/" + this.repo + s) + (this.file ? "/blob/" + branch + "/" + this.file : "");
        this.apiUrl = ("https://api.github.com/repos/" + this.owner + "/" + this.repo + "/contents" + s) + (this.file ? "/" + this.file : "");
      } else {
        this.source = this.url;
      }
      console.log(this);
    }

    ResourceLocation.prototype.getGistId = function() {
      var h, p;
      this.query = this.search.slice(1);
      if (!this.query) {
        return null;
      }
      h = this.query.split("&");
      p = h != null ? h[0].split("=") : void 0;
      return this.gistId = p.length && p[0] === "gist" ? p[1] : null;
    };

    return ResourceLocation;

  })();

  Resource = (function() {

    function Resource(spec) {
      var _ref, _ref1;
      this.spec = spec;
      this.location = (_ref = this.spec.location) != null ? _ref : new ResourceLocation(this.spec.url);
      this.url = this.location.url;
      this.fileExt = (_ref1 = this.spec.fileExt) != null ? _ref1 : this.location.fileExt;
      this.id = this.spec.id;
      this.loaded = false;
      this.head = document.head;
      this.containers = new ResourceContainers(this);
    }

    Resource.prototype.load = function(callback, type) {
      var process, success, thisHost, url,
        _this = this;
      if (type == null) {
        type = "text";
      }
      if (this.spec.gistSource) {
        this.content = this.spec.gistSource;
        this.postLoad(callback);
        return;
      }
      thisHost = window.location.hostname;
      console.log("location", this.location);
      if ((this.location.host !== thisHost || this.location.isGitHub) && this.location.apiUrl) {
        console.log("foreign");
        url = this.location.apiUrl;
        type = "json";
        process = function(data) {
          var content;
          content = data.content.replace(/\s/g, '');
          return atob(content);
        };
      } else {
        url = this.url + ("?t=" + (Date.now()));
        process = null;
      }
      success = function(data) {
        _this.content = process ? process(data) : data;
        return _this.postLoad(callback);
      };
      return $.get(url, success, type);
    };

    Resource.prototype.postLoad = function(callback) {
      this.loaded = true;
      return typeof callback === "function" ? callback() : void 0;
    };

    Resource.prototype.isType = function(type) {
      return this.fileExt === type;
    };

    Resource.prototype.setContent = function(content) {
      this.content = content;
      return this.containers.setEditorContent(this.content);
    };

    Resource.prototype.setFromEditor = function(editor) {
      this.content = editor.code();
      return this.containers.setFromEditor(editor);
    };

    Resource.prototype.update = function(content) {
      this.content = content;
      return console.log("No update method for " + this.url);
    };

    Resource.prototype.updateFromContainers = function() {
      return this.containers.updateResource();
    };

    Resource.prototype.hasEval = function() {
      return this.containers.evals().length;
    };

    Resource.prototype.render = function() {
      return this.containers.render();
    };

    Resource.prototype.getEvalContainer = function() {
      return this.containers.getEvalContainer();
    };

    Resource.prototype.inBlab = function() {
      return this.location.inBlab;
    };

    Resource.typeFilter = function(types) {
      return function(resource) {
        var type, _i, _len;
        if (typeof types === "string") {
          return resource.isType(types);
        } else {
          for (_i = 0, _len = types.length; _i < _len; _i++) {
            type = types[_i];
            if (resource.isType(type)) {
              return true;
            }
          }
          return false;
        }
      };
    };

    return Resource;

  })();

  ResourceContainers = (function() {

    ResourceContainers.prototype.fileContainerAttr = "data-file";

    ResourceContainers.prototype.evalContainerAttr = "data-eval";

    function ResourceContainers(resource) {
      this.resource = resource;
      this.url = this.resource.url;
    }

    ResourceContainers.prototype.render = function() {
      var file, idx, node, _i, _len, _ref, _ref1, _results;
      this.fileNodes = (function() {
        var _i, _len, _ref, _results;
        _ref = this.files();
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          node = _ref[_i];
          _results.push(new Ace.EditorNode($(node), this.resource));
        }
        return _results;
      }).call(this);
      this.evalNodes = (function() {
        var _i, _len, _ref, _results;
        _ref = this.evals();
        _results = [];
        for (idx = _i = 0, _len = _ref.length; _i < _len; idx = ++_i) {
          node = _ref[idx];
          _results.push(new Ace.EvalNode($(node), this.resource, this.fileNodes[idx]));
        }
        return _results;
      }).call(this);
      if ((_ref = $pz.codeNode) == null) {
        $pz.codeNode = {};
      }
      _ref1 = this.files;
      _results = [];
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        file = _ref1[_i];
        _results.push($pz.codeNode[file.editor.id] = file.editor);
      }
      return _results;
    };

    ResourceContainers.prototype.getEvalContainer = function() {
      var _ref;
      if (((_ref = this.evalNodes) != null ? _ref.length : void 0) !== 1) {
        return null;
      }
      return this.evalNodes[0].container;
    };

    ResourceContainers.prototype.setEditorContent = function(content) {
      var node, triggerChange, _i, _len, _ref, _results;
      triggerChange = false;
      _ref = this.fileNodes;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        node = _ref[_i];
        _results.push(node.setCode(triggerChange));
      }
      return _results;
    };

    ResourceContainers.prototype.setFromEditor = function(editor) {
      var node, triggerChange, _i, _len, _ref, _results;
      triggerChange = false;
      _ref = this.fileNodes;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        node = _ref[_i];
        if (node.editor.id !== editor.id) {
          _results.push(node.setCode(triggerChange));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    ResourceContainers.prototype.updateResource = function() {
      if (!this.fileNodes.length) {
        return;
      }
      if (this.fileNodes.length > 1) {
        console.log("Multiple editor nodes for resource.  Updating resource from only first editor node.", this.resource);
      }
      return this.resource.update(this.fileNodes[0].code());
    };

    ResourceContainers.prototype.files = function() {
      return $("div[" + this.fileContainerAttr + "='" + this.url + "']");
    };

    ResourceContainers.prototype.evals = function() {
      return $("div[" + this.evalContainerAttr + "='" + this.url + "']");
    };

    return ResourceContainers;

  })();

  EditorContainer = (function() {

    function EditorContainer(resource, div) {
      this.resource = resource;
      this.div = div;
      this.node = new Ace.EditorNode(this.div, this.resource);
    }

    EditorContainer.prototype.updateResource = function() {
      return this.resource.update(this.node.code());
    };

    return EditorContainer;

  })();

  EvalContainer = (function() {

    function EvalContainer(resource, div) {
      this.resource = resource;
      this.div = div;
      this.node = new Ace.EvalNode(this.div, this.resource);
    }

    EvalContainer.prototype.getContainer = function() {
      return this.node.container;
    };

    return EvalContainer;

  })();

  HtmlResource = (function(_super) {

    __extends(HtmlResource, _super);

    function HtmlResource() {
      return HtmlResource.__super__.constructor.apply(this, arguments);
    }

    HtmlResource.prototype.update = function(content) {
      this.content = content;
      return $pz.renderHtml();
    };

    return HtmlResource;

  })(Resource);

  ResourceInline = (function(_super) {

    __extends(ResourceInline, _super);

    function ResourceInline() {
      return ResourceInline.__super__.constructor.apply(this, arguments);
    }

    ResourceInline.prototype.load = function(callback) {
      var _this = this;
      return ResourceInline.__super__.load.call(this, function() {
        _this.createElement();
        return typeof callback === "function" ? callback() : void 0;
      });
    };

    ResourceInline.prototype.createElement = function() {
      this.element = $("<" + this.tag + ">", {
        type: this.mime,
        "data-url": this.url
      });
      return this.element.text(this.content);
    };

    ResourceInline.prototype.inDom = function() {
      return $("" + this.tag + "[data-url='" + this.url + "']").length;
    };

    ResourceInline.prototype.appendToHead = function() {
      if (!this.inDom()) {
        return this.head.appendChild(this.element[0]);
      }
    };

    ResourceInline.prototype.update = function(content) {
      this.content = content;
      this.head.removeChild(this.element[0]);
      this.createElement();
      return this.appendToHead();
    };

    return ResourceInline;

  })(Resource);

  CssResourceInline = (function(_super) {

    __extends(CssResourceInline, _super);

    function CssResourceInline() {
      return CssResourceInline.__super__.constructor.apply(this, arguments);
    }

    CssResourceInline.prototype.tag = "style";

    CssResourceInline.prototype.mime = "text/css";

    return CssResourceInline;

  })(ResourceInline);

  CssResourceLinked = (function(_super) {

    __extends(CssResourceLinked, _super);

    function CssResourceLinked() {
      return CssResourceLinked.__super__.constructor.apply(this, arguments);
    }

    CssResourceLinked.prototype.load = function(callback) {
      var t,
        _this = this;
      this.style = document.createElement("link");
      this.style.setAttribute("type", "text/css");
      this.style.setAttribute("rel", "stylesheet");
      t = Date.now();
      this.style.setAttribute("href", this.url);
      setTimeout((function() {
        return _this.postLoad(callback);
      }), 0);
      return this.head.appendChild(this.style);
    };

    return CssResourceLinked;

  })(Resource);

  JsResourceInline = (function(_super) {

    __extends(JsResourceInline, _super);

    function JsResourceInline() {
      return JsResourceInline.__super__.constructor.apply(this, arguments);
    }

    JsResourceInline.prototype.tag = "script";

    JsResourceInline.prototype.mime = "text/javascript";

    return JsResourceInline;

  })(ResourceInline);

  JsResourceLinked = (function(_super) {

    __extends(JsResourceLinked, _super);

    function JsResourceLinked() {
      return JsResourceLinked.__super__.constructor.apply(this, arguments);
    }

    JsResourceLinked.prototype.load = function(callback) {
      var cache, t,
        _this = this;
      this.script = document.createElement("script");
      this.script.setAttribute("type", "text/javascript");
      this.head.appendChild(this.script);
      this.script.onload = function() {
        return _this.postLoad(callback);
      };
      t = Date.now();
      cache = this.url.indexOf("/puzlet/js") !== -1 || this.url.indexOf("http://") !== -1;
      return this.script.setAttribute("src", this.url + (cache ? "" : "?t=" + t));
    };

    return JsResourceLinked;

  })(Resource);

  CoffeeResource = (function(_super) {

    __extends(CoffeeResource, _super);

    function CoffeeResource() {
      return CoffeeResource.__super__.constructor.apply(this, arguments);
    }

    CoffeeResource.prototype.load = function(callback) {
      var _this = this;
      return CoffeeResource.__super__.load.call(this, function() {
        var spec;
        spec = {
          id: _this.url
        };
        _this.compiler = _this.hasEval() || _this.spec.orig.doEval ? $coffee.evaluator(spec) : $coffee.compiler(spec);
        return typeof callback === "function" ? callback() : void 0;
      });
    };

    CoffeeResource.prototype.compile = function() {
      $blab.evaluatingResource = this;
      this.compiler.compile(this.content);
      this.resultArray = this.compiler.resultArray;
      this.resultStr = this.compiler.result;
      return $.event.trigger("compiledCoffeeScript", {
        url: this.url
      });
    };

    CoffeeResource.prototype.update = function(content) {
      this.content = content;
      return this.compile();
    };

    return CoffeeResource;

  })(Resource);

  JsonResource = (function(_super) {

    __extends(JsonResource, _super);

    function JsonResource() {
      return JsonResource.__super__.constructor.apply(this, arguments);
    }

    return JsonResource;

  })(Resource);

  ResourceFactory = (function() {

    ResourceFactory.prototype.resourceTypes = {
      html: {
        all: HtmlResource
      },
      css: {
        blab: CssResourceInline,
        ext: CssResourceLinked,
        api: CssResourceInline
      },
      js: {
        blab: JsResourceInline,
        ext: JsResourceLinked,
        api: JsResourceInline
      },
      coffee: {
        all: CoffeeResource
      },
      json: {
        all: JsonResource
      },
      py: {
        all: Resource
      },
      m: {
        all: Resource
      },
      svg: {
        all: Resource
      },
      txt: {
        all: Resource
      }
    };

    function ResourceFactory(blabLocation, getGistSource) {
      this.blabLocation = blabLocation;
      this.getGistSource = getGistSource;
    }

    ResourceFactory.prototype.create = function(spec) {
      var fileExt, location, resource, subTypes, subtype, url, _ref;
      if (this.checkExists(spec)) {
        return null;
      }
      if (spec.url) {
        url = spec.url;
      } else {
        _ref = this.extractUrl(spec), url = _ref.url, fileExt = _ref.fileExt;
      }
      location = new ResourceLocation(url);
      if (fileExt == null) {
        fileExt = location.fileExt;
      }
      spec = {
        id: spec.id,
        location: location,
        fileExt: fileExt,
        gistSource: this.getGistSource(url),
        orig: spec
      };
      subTypes = this.resourceTypes[fileExt];
      if (!subTypes) {
        return null;
      }
      if (subTypes.all != null) {
        resource = new subTypes.all(spec);
      } else {
        subtype = (function() {
          switch (false) {
            case !location.inBlab:
              return "blab";
            case !location.isGitHubApi:
              return "api";
            default:
              return "ext";
          }
        })();
        resource = new subTypes[subtype](spec);
      }
      return resource;
    };

    ResourceFactory.prototype.checkExists = function(spec) {
      var v, vars, x, z, _i, _len;
      v = spec["var"];
      if (!v) {
        return false;
      }
      vars = v != null ? v.split(".") : void 0;
      z = window;
      for (_i = 0, _len = vars.length; _i < _len; _i++) {
        x = vars[_i];
        z = z[x];
        if (!z) {
          return false;
        }
      }
      console.log("Not loading " + v + " - already exists");
      return true;
    };

    ResourceFactory.prototype.extractUrl = function(spec) {
      var fileExt, p, url, v;
      for (p in spec) {
        v = spec[p];
        url = v;
        fileExt = p;
      }
      return {
        url: url,
        fileExt: fileExt
      };
    };

    ResourceFactory.prototype.modifyPuzletUrl = function(url) {
      var puzletResource, puzletUrl, _ref, _ref1;
      puzletUrl = "http://puzlet.org";
      if ((_ref = this.puzlet) == null) {
        this.puzlet = document.querySelectorAll("[src='" + puzletUrl + "/puzlet/js/puzlet.js']").length ? puzletUrl : null;
      }
      puzletResource = (_ref1 = url.match("^/puzlet")) != null ? _ref1.length : void 0;
      if (puzletResource) {
        url = this.puzlet ? this.puzlet + url : "/puzlet" + url;
      }
      return url;
    };

    return ResourceFactory;

  })();

  Resources = (function() {

    function Resources(blabLocation) {
      var _this = this;
      this.blabLocation = blabLocation;
      this.resources = [];
      this.factory = new ResourceFactory(this.blabLocation, function(url) {
        return _this.getGistSource(url);
      });
      this.changed = false;
    }

    Resources.prototype.add = function(resourceSpecs) {
      var newResources, resource, spec, _i, _len;
      if (!resourceSpecs.length) {
        resourceSpecs = [resourceSpecs];
      }
      newResources = [];
      for (_i = 0, _len = resourceSpecs.length; _i < _len; _i++) {
        spec = resourceSpecs[_i];
        resource = this.factory.create(spec);
        if (!resource) {
          continue;
        }
        newResources.push(resource);
        this.resources.push(resource);
      }
      if (newResources.length === 1) {
        return newResources[0];
      } else {
        return newResources;
      }
    };

    Resources.prototype.load = function(filter, loaded) {
      var resource, resourceLoaded, resources, resourcesToLoad, _i, _len, _results,
        _this = this;
      filter = this.filterFunction(filter);
      resources = this.select(function(resource) {
        return !resource.loaded && filter(resource);
      });
      if (resources.length === 0) {
        if (typeof loaded === "function") {
          loaded();
        }
        return;
      }
      resourcesToLoad = 0;
      resourceLoaded = function(resource) {
        resourcesToLoad--;
        if (resourcesToLoad === 0) {
          _this.appendToHead(filter);
          return typeof loaded === "function" ? loaded() : void 0;
        }
      };
      _results = [];
      for (_i = 0, _len = resources.length; _i < _len; _i++) {
        resource = resources[_i];
        resourcesToLoad++;
        _results.push(resource.load(function() {
          return resourceLoaded(resource);
        }));
      }
      return _results;
    };

    Resources.prototype.loadUnloaded = function(loaded) {
      return this.load((function() {
        return true;
      }), loaded);
    };

    Resources.prototype.appendToHead = function(filter) {
      var resource, resources, _i, _len, _results;
      filter = this.filterFunction(filter);
      resources = this.select(function(resource) {
        return !(typeof resource.inDom === "function" ? resource.inDom() : void 0) && (resource.appendToHead != null) && filter(resource);
      });
      _results = [];
      for (_i = 0, _len = resources.length; _i < _len; _i++) {
        resource = resources[_i];
        _results.push(resource.appendToHead());
      }
      return _results;
    };

    Resources.prototype.select = function(filter) {
      var resource, _i, _len, _ref, _results;
      filter = this.filterFunction(filter);
      _ref = this.resources;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        resource = _ref[_i];
        if (filter(resource)) {
          _results.push(resource);
        }
      }
      return _results;
    };

    Resources.prototype.filterFunction = function(filter) {
      if (typeof filter === "function") {
        return filter;
      } else {
        return Resource.typeFilter(filter);
      }
    };

    Resources.prototype.find = function(id) {
      var f, resource,
        _this = this;
      f = function(p) {
        var r, _i, _len, _ref;
        _ref = _this.resources;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          r = _ref[_i];
          if (r[p] === id) {
            return r;
          }
        }
        return null;
      };
      resource = f("id");
      if (resource) {
        return resource;
      }
      return resource = f("url");
    };

    Resources.prototype.getContent = function(id) {
      var content, resource;
      resource = this.find(id);
      if (resource) {
        content = resource.content;
        if (resource.fileExt === "json") {
          return JSON.parse(content);
        } else {
          return content;
        }
      } else {
        return null;
      }
    };

    Resources.prototype.getJSON = function(id) {
      var content;
      content = this.getContent(id);
      if (content) {
        return JSON.parse(content);
      }
    };

    Resources.prototype.loadJSON = function(url, callback) {
      var resource;
      resource = this.find(url);
      if (resource == null) {
        resource = this.add({
          url: url
        });
      }
      if (!resource) {
        return null;
      }
      return resource.load((function() {
        return typeof callback === "function" ? callback(resource.content) : void 0;
      }), "json");
    };

    Resources.prototype.render = function() {
      var resource, _i, _len, _ref, _results;
      _ref = this.resources;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        resource = _ref[_i];
        _results.push(resource.render());
      }
      return _results;
    };

    Resources.prototype.setGistResources = function(gistFiles) {
      this.gistFiles = gistFiles;
    };

    Resources.prototype.getGistSource = function(url) {
      var _ref, _ref1, _ref2;
      return (_ref = (_ref1 = this.gistFiles) != null ? (_ref2 = _ref1[url]) != null ? _ref2.content : void 0 : void 0) != null ? _ref : null;
    };

    Resources.prototype.updateFromContainers = function() {
      var resource, _i, _len, _ref, _results;
      _ref = this.resources;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        resource = _ref[_i];
        if (resource.edited) {
          _results.push(resource.updateFromContainers());
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    return Resources;

  })();

  new Blab;

}).call(this);
