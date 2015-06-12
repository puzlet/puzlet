// Generated by CoffeeScript 1.7.1

/*
TODO:
* use full file path instead of subf - is subf by itself ever really needed?
* if localhost, try loading resource locally first.  if fails, from github.
* support {css: "..."} in resources.coffee
* loadJSON broken - Resource.load no longer supports type?
* have local env file so we know whether to try loading locally (localhost or deployed host)?
* for deployed host, may also need to know root folder?
 */

(function() {
  var BlabResourceLocation, CoffeeResource, CssResourceInline, CssResourceLinked, GitHub, GitHubApi, GitHubApiResourceLocation, HtmlResource, JsResourceInline, JsResourceLinked, JsonResource, Resource, ResourceFactory, ResourceInline, ResourceLocation, Resources, URL, WebResourceLocation, resourceLocation, resources, testBlabLocation,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  console.log("Puzlet loader");


  /*
  resources
    load: [
      "main.html"
      "style.css"
      "bar.js"
      "foo.coffee"
      "main.coffee"
      "/some-org/some-repo/snippet.html",
      "/other-org/other-repo/foo.css",
      "/puzlet/puzlet/js/d3.min.js", # check this
      "http://domain.com/script.js",
      "/org/ode-fixed/ode.coffee"
  ]    
  
  ******* SPECIFICATION *******
          
  ===Supported URLs for current blab location===
  TODO: is stuff below for puzlet bootstrap?
  http://localhost:port/owner/repo (note: repo could be owner.github.io)
  http://puzlet.org
  http://puzlet.org/repo
  http://owner.github.io
  http://owner.github.io/repo
  (We could also support subfolders)
  TODO: should work on any domain (http://domain.com/path/to/owner[/repo]), if blabs deployed there.
  
  From these, we derive:
  owner, repo names of current page (index.html).
  
  ===For resources.coffee, support these URLs===
  
  File extension affects whether resource is linked or inlined.
  JS/CSS files are linked (not inlined), unless they come from current blab (then they are inlined).
  All other file types are loaded via Ajax (if possible), and inlined.  Use GitHub API if foreign.  IE issue here.
  TODO: Also need {css/js: generalUrl}.
  
  ---General URLs---
  Must begin with http:// or //
  (No special interpretation of owner/repo.)
  
  http://general.com/path/to/file.ext (general URL)
  http://puzlet.org/repo/path/to/file.ext
  http://owner.github.io/repo/path/to/file.ext
  http://rawgit ...
  
  GitHub API link.  This needs to be used for foreign github JS/CSS resources
  that can't be accessed via github.io.
  This does not work with IE, and so it may be better to copy such resource to location in same org,
  so it is accessible locally or via github.io.
  http://api.github.com/...
  
  ---Special resource identifiers---
  Load locally if localhost (TODO: or deployment domain) and file available; otherwise get from github.
  
  /owner/repo/path/to/file.ext 
  path/to/file.ext (use current page's host owner/repo)
   */

  URL = (function() {
    function URL(url) {
      var match;
      this.url = url;
      this.a = document.createElement("a");
      this.a.href = this.url;
      this.hostname = this.a.hostname;
      this.pathname = this.a.pathname;
      this.search = this.a.search;
      this.host = this.hostname.split(".");
      this.path = this.pathname ? this.pathname.split("/").slice(1) : [];
      this.hasPath = this.path.length > 0;
      match = this.hasPath ? this.pathname.match(/\.[0-9a-z]+$/i) : null;
      this.fileExt = (match != null ? match.length : void 0) ? match[0].slice(1) : null;
      this.file = this.fileExt ? this.path.slice(-1)[0] : null;
    }

    URL.prototype.onWeb = function() {
      var w;
      w = (function(_this) {
        return function(url) {
          return _this.url.indexOf(url) === 0;
        };
      })(this);
      return w("http://") || w("https://") || w("//");
    };

    URL.prototype.filePath = function() {
      var base;
      base = new URL(".");
      return this.pathname.replace(base.pathname, "");
    };

    URL.prototype.subfolder = function(filePathIdx) {
      var endIdx, s;
      endIdx = this.file ? -2 : -1;
      s = this.path.slice(filePathIdx, +endIdx + 1 || 9e9).join("/");
      if (s) {
        return "/" + s;
      } else {
        return "";
      }
    };

    return URL;

  })();

  ResourceLocation = (function(_super) {
    __extends(ResourceLocation, _super);

    ResourceLocation.prototype.owner = null;

    ResourceLocation.prototype.repo = null;

    ResourceLocation.prototype.filepath = null;

    ResourceLocation.prototype.inBlab = false;

    ResourceLocation.prototype.source = null;

    ResourceLocation.prototype.gitHub = null;

    function ResourceLocation(url) {
      this.url = url;
      ResourceLocation.__super__.constructor.call(this, this.url);
      this.source = this.url;
      this.loadUrl = this.url;
    }

    ResourceLocation.prototype.load = function(callback) {
      var url;
      url = this.url + ("?t=" + (Date.now()));
      console.log("LOAD " + url);
      return $.get(url, (function(data) {
        return callback(data);
      }), "text");
    };

    return ResourceLocation;

  })(URL);

  WebResourceLocation = (function(_super) {
    __extends(WebResourceLocation, _super);

    function WebResourceLocation() {
      return WebResourceLocation.__super__.constructor.apply(this, arguments);
    }

    WebResourceLocation.prototype.loadType = "ext";

    WebResourceLocation.prototype.cache = true;

    return WebResourceLocation;

  })(ResourceLocation);

  BlabResourceLocation = (function(_super) {
    __extends(BlabResourceLocation, _super);

    BlabResourceLocation.prototype.localOrgPath = null;

    BlabResourceLocation.prototype.loadType = null;

    BlabResourceLocation.prototype.cache = null;

    function BlabResourceLocation(url) {
      var path, _ref, _ref1, _ref2;
      this.url = url;
      BlabResourceLocation.__super__.constructor.call(this, this.url);
      this.blabOwner = $blab.gitHub.owner;
      this.blabRepo = $blab.gitHub.repo;
      if (this.fullPath()) {
        this.owner = this.path[0];
        this.repo = this.path[1];
        this.filepath = this.path.slice(2).join("/");
        this.inBlab = this.owner === this.blabOwner && this.repo === this.blabRepo;
      } else {
        this.owner = this.blabOwner;
        this.repo = this.blabRepo;
        this.filepath = this.filePath();
        this.inBlab = true;
      }
      this.localOrgPath = (_ref = $blab.gitHub) != null ? (_ref1 = _ref.localConfig) != null ? (_ref2 = _ref1.orgs) != null ? _ref2[this.owner] : void 0 : void 0 : void 0;
      path = this.filepath;
      this.gitHub = new GitHub({
        owner: this.owner,
        repo: this.repo,
        path: path
      });
      if (this.inBlab) {
        this.loadUrl = this.filepath;
      } else {
        this.loadUrl = this.localOrgPath ? "" + this.localOrgPath + "/" + this.repo + "/" + this.filepath : this.gitHub.linkedUrl();
      }
      this.loadType = this.inBlab ? "blab" : "ext";
      this.cache = false;
      this.source = this.gitHub.sourcePageUrl();
    }

    BlabResourceLocation.prototype.load = function(callback) {
      var url;
      url = this.loadUrl + ("?t=" + (Date.now()));
      return $.get(url, (function(data) {
        return callback(data);
      }), "text");
    };

    BlabResourceLocation.prototype.fullPath = function() {
      var _ref;
      return ((_ref = this.url) != null ? _ref.indexOf("/") : void 0) === 0;
    };

    return BlabResourceLocation;

  })(ResourceLocation);

  GitHubApiResourceLocation = (function(_super) {
    __extends(GitHubApiResourceLocation, _super);

    GitHubApiResourceLocation.prototype.loadType = "api";

    GitHubApiResourceLocation.prototype.cache = false;

    function GitHubApiResourceLocation(url) {
      this.url = url;
      GitHubApiResourceLocation.__super__.constructor.call(this, this.url);
      this.api = new GitHubApi(this.url);
      if (!this.api.owner) {
        return;
      }
      this.owner = this.api.owner;
      this.repo = this.api.repo;
      this.path = this.api.path;
      this.gitHub = new GitHub({
        owner: this.owner,
        repo: this.repo,
        path: this.path
      });
      this.source = this.gitHub.sourcePageUrl();
    }

    GitHubApiResourceLocation.prototype.load = function(callback) {
      return this.api.load(callback);
    };

    return GitHubApiResourceLocation;

  })(ResourceLocation);

  resourceLocation = function(url) {
    var R, resource;
    resource = new URL(url);
    if (GitHubApi.isApiUrl(resource.url)) {
      R = GitHubApiResourceLocation;
    } else if (resource.onWeb()) {
      R = WebResourceLocation;
    } else {
      R = BlabResourceLocation;
    }
    return new R(url);
  };

  GitHub = (function() {
    GitHub.prototype.knownGitHubOrgDomains = [
      {
        domain: "puzlet.org",
        org: "puzlet"
      }
    ];

    GitHub.prototype.branch = "gh-pages";

    GitHub.isIoUrl = function(url) {
      var host, u;
      u = new URL(url);
      host = u.host;
      return host.length === 3 && host[1] === "github" && host[2] === "io";
    };

    function GitHub(spec) {
      var _ref;
      this.spec = spec;
      _ref = this.spec, this.owner = _ref.owner, this.repo = _ref.repo, this.path = _ref.path;
    }

    GitHub.prototype.sourcePageUrl = function() {
      if (!this.owner) {
        return null;
      }
      return "https://github.com/" + this.owner + "/" + this.repo + "/blob/" + this.branch + "/" + this.path;
    };

    GitHub.prototype.linkedUrl = function() {
      var host, known;
      if (!this.owner) {
        return null;
      }
      known = this.knownGitHubOrgDomains.filter((function(_this) {
        return function(d) {
          return _this.owner === d.org;
        };
      })(this));
      host = known.length ? known[0].domain : "" + this.owner + ".github.io";
      return "http://" + host + "/" + this.repo + "/" + this.path;
    };

    GitHub.prototype.apiUrl = function() {
      if (!this.owner) {
        return null;
      }
      return GitHubApi.getUrl({
        owner: this.owner,
        repo: this.repo,
        path: this.path
      });
    };

    GitHub.prototype.urls = function() {
      return {
        sourcePageUrl: this.sourcePageUrl(),
        linkedUrl: this.linkedUrl(),
        apiUrl: this.apiUrl()
      };
    };

    return GitHub;

  })();

  GitHubApi = (function(_super) {
    __extends(GitHubApi, _super);

    GitHubApi.hostname = "api.github.com";

    GitHubApi.isApiUrl = function(url) {
      var path, u;
      u = new URL(url);
      path = u.path;
      return u.hostname === GitHubApi.hostname && path.length >= 5 && path[0] === "repos" && path[3] === "contents";
    };

    GitHubApi.getUrl = function(spec) {
      var owner, path, repo;
      owner = spec.owner, repo = spec.repo, path = spec.path;
      return "https://" + GitHubApi.hostname + "/repos/" + owner + "/" + repo + "/contents/" + path;
    };

    GitHubApi.loadParameters = function(url) {
      return {
        type: "json",
        process: function(data) {
          var content;
          content = data.content.replace(/\s/g, '');
          return atob(content);
        }
      };
    };

    function GitHubApi(url) {
      this.url = url;
      GitHubApi.__super__.constructor.call(this, this.url);
      if (!GitHubApi.isApiUrl(this.url)) {
        return;
      }
      this.owner = this.path[1];
      this.repo = this.path[2];
    }

    GitHubApi.prototype.load = function(callback) {
      var success;
      success = (function(_this) {
        return function(data) {
          var content;
          content = data.content.replace(/\s/g, '');
          return callback(atob(content));
        };
      })(this);
      return $.get(this.url, success, "json");
    };

    return GitHubApi;

  })(URL);

  Resource = (function() {
    function Resource(spec) {
      var _ref, _ref1;
      this.spec = spec;
      this.location = (_ref = this.spec.location) != null ? _ref : resourceLocation(this.spec.url);
      this.url = this.location.url;
      this.loadUrl = this.location.loadUrl;
      this.fileExt = (_ref1 = this.spec.fileExt) != null ? _ref1 : this.location.fileExt;
      this.id = this.spec.id;
      this.loaded = false;
      this.head = document.head;
    }

    Resource.prototype.load = function(callback) {
      var source, _ref;
      source = (_ref = this.spec.orig.source) != null ? _ref : this.spec.source;
      if (source != null) {
        this.content = source;
        return this.postLoad(callback);
      } else {
        return this.location.load((function(_this) {
          return function(content) {
            _this.content = content;
            return _this.postLoad(callback);
          };
        })(this));
      }
    };

    Resource.prototype.postLoad = function(callback) {
      this.loaded = true;
      return typeof callback === "function" ? callback() : void 0;
    };

    Resource.prototype.isType = function(type) {
      return this.fileExt === type;
    };

    Resource.prototype.update = function(content) {
      this.content = content;
      return console.log("No update method for " + this.url);
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
      return ResourceInline.__super__.load.call(this, (function(_this) {
        return function() {
          _this.createElement();
          return typeof callback === "function" ? callback() : void 0;
        };
      })(this));
    };

    ResourceInline.prototype.createElement = function() {
      this.element = $("<" + this.tag + ">", this.mime ? {
        type: this.mime
      } : void 0, {
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
      var t;
      this.style = document.createElement("link");
      this.style.setAttribute("rel", "stylesheet");
      t = Date.now();
      this.style.setAttribute("href", this.loadUrl);
      setTimeout(((function(_this) {
        return function() {
          return _this.postLoad(callback);
        };
      })(this)), 0);
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

    return JsResourceInline;

  })(ResourceInline);

  JsResourceLinked = (function(_super) {
    __extends(JsResourceLinked, _super);

    function JsResourceLinked() {
      return JsResourceLinked.__super__.constructor.apply(this, arguments);
    }

    JsResourceLinked.prototype.load = function(callback) {
      var src, t;
      this.script = document.createElement("script");
      this.head.appendChild(this.script);
      this.script.onload = (function(_this) {
        return function() {
          return _this.postLoad(callback);
        };
      })(this);
      src = this.loadUrl;
      t = this.location.cache ? "" : "?t=" + (Date.now());
      return this.script.setAttribute("src", src + t);
    };

    return JsResourceLinked;

  })(Resource);

  CoffeeResource = (function(_super) {
    __extends(CoffeeResource, _super);

    CoffeeResource.preCompileCode = {};

    function CoffeeResource(spec) {
      this.spec = spec;
      CoffeeResource.__super__.constructor.call(this, this.spec);
      this.observers = {
        preCompile: []
      };
    }

    CoffeeResource.prototype.load = function(callback) {
      $.event.trigger("loadCoffeeResource", {
        resource: this
      });
      return CoffeeResource.__super__.load.call(this, (function(_this) {
        return function() {
          _this.setEval(false);
          _this.setCompilerSpec({});
          _this.mathSpecSet = false;
          _this.compiled = false;
          return typeof callback === "function" ? callback() : void 0;
        };
      })(this));
    };

    CoffeeResource.prototype.setEval = function(doEval) {
      this.doEval = doEval;
    };

    CoffeeResource.prototype.setCompilerSpec = function(spec) {
      var _ref;
      spec.id = this.url;
      this.compiler = this.doEval || this.spec.orig.doEval ? $coffee.evaluator(spec) : $coffee.compiler(spec);
      return this.extraLines = (_ref = spec.extraLines) != null ? _ref : (function() {
        return "";
      });
    };

    CoffeeResource.prototype.compile = function(recompile) {
      var _ref;
      if (recompile == null) {
        recompile = false;
      }
      this.setMathSpec();
      $.event.trigger("preCompileCoffee", {
        resource: this
      });
      this.compiler.compile(this.content, recompile);
      this.compiled = true;
      this.resultArray = this.compiler.resultArray;
      this.resultStr = ((_ref = this.compiler.result) != null ? _ref.join("\n") : void 0) + this.extraLines(this.resultArray);
      return $.event.trigger("compiledCoffeeScript", {
        url: this.url
      });
    };

    CoffeeResource.prototype.update = function(content) {
      var recompile;
      this.content = content;
      recompile = true;
      return this.compile(recompile);
    };

    CoffeeResource.prototype.on = function(evt, observer) {
      return this.observers[evt].push(observer);
    };

    CoffeeResource.prototype.setMathSpec = function() {
      var bare, isMain, spec;
      if (!((typeof $mathCoffee !== "undefined" && $mathCoffee !== null) && !this.mathSpecSet)) {
        return;
      }
      bare = false;
      isMain = this.inBlab();
      spec = {
        compile: (function(_this) {
          return function(code) {
            return $mathCoffee.compile(_this.preCompile(code), bare, isMain);
          };
        })(this),
        evaluate: (function(_this) {
          return function(code, js) {
            return $mathCoffee.evaluate(_this.preCompile(code), js, isMain);
          };
        })(this),
        extraLines: function(resultArray) {
          return $mathCoffee.extraLines(resultArray);
        }
      };
      this.setCompilerSpec(spec);
      return this.mathSpecSet = true;
    };

    CoffeeResource.prototype.preCompile = function(code) {
      var observer, pc, preCompileCode, _i, _len, _ref;
      preCompileCode = CoffeeResource.preCompileCode;
      pc = preCompileCode[this.url];
      if (pc) {
        code = pc.preamble + code + pc.postamble;
      }
      _ref = this.observers.preCompile;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        observer = _ref[_i];
        code = observer({
          code: code
        });
      }
      return code;
    };

    CoffeeResource.registerPrecompileCode = function(preCompileCode) {
      return CoffeeResource.preCompileCode = preCompileCode;
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

    function ResourceFactory(getSource) {
      this.getSource = getSource;
    }

    ResourceFactory.prototype.create = function(spec) {
      var fileExt, location, resource, subTypes, subtype, url, _ref;
      console.log("LOAD", spec.url);
      if (this.checkExists(spec)) {
        return null;
      }
      if (spec.url) {
        url = spec.url;
      } else {
        _ref = this.extractUrl(spec), url = _ref.url, fileExt = _ref.fileExt;
      }
      location = resourceLocation(url);
      if (fileExt == null) {
        fileExt = location.fileExt;
      }
      spec = {
        id: spec.id,
        location: location,
        fileExt: fileExt,
        source: this.getSource(url),
        orig: spec
      };
      subTypes = this.resourceTypes[fileExt];
      if (!subTypes) {
        return null;
      }
      subtype = subTypes.all != null ? "all" : location.loadType;
      return resource = new subTypes[subtype](spec);
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

    return ResourceFactory;

  })();

  Resources = (function() {
    Resources.prototype.coreResources = [
      {
        url: "/puzlet/coffeescript/coffeescript.js"
      }, {
        url: "/puzlet/coffeescript/compiler.js"
      }, {
        url: "/puzlet/puzlet/js/github.js"
      }, {
        url: "/puzlet/puzlet/js/google_analytics.js"
      }
    ];

    Resources.prototype.resourcesSpec = "/puzlet/puzlet/resources.coffee";

    function Resources(spec) {
      this.resources = [];
      this.factory = new ResourceFactory((function(_this) {
        return function(url) {
          return typeof _this.getSource === "function" ? _this.getSource(url) : void 0;
        };
      })(this));
      this.changed = false;
      this.observers = {
        preload: [],
        postload: [],
        ready: []
      };
    }

    Resources.prototype.init = function(spec) {
      var core, getResourcesUrl, postload, preload, ready, resources;
      core = (function(_this) {
        return function(cb) {
          return _this.addAndLoad(_this.coreResources, cb);
        };
      })(this);
      getResourcesUrl = (function(_this) {
        return function() {
          var pzAttr, pzScript;
          pzAttr = "data-resources";
          pzScript = $("script[" + pzAttr + "]");
          if (pzScript.length) {
            return pzScript.attr(pzAttr);
          } else {
            return _this.resourcesSpec;
          }
        };
      })(this);
      resources = (function(_this) {
        return function(cb) {
          return _this.loadFromSpecFile({
            url: getResourcesUrl(),
            callback: function() {
              return cb();
            }
          });
        };
      })(this);
      preload = (function(_this) {
        return function(cb) {
          return _this.triggerAndWait("preload", [], function() {
            if (spec != null) {
              if (typeof spec.preload === "function") {
                spec.preload();
              }
            }
            return cb();
          });
        };
      })(this);
      postload = (function(_this) {
        return function(cb) {
          _this.trigger("postload");
          if (spec != null) {
            if (typeof spec.postload === "function") {
              spec.postload();
            }
          }
          return typeof cb === "function" ? cb() : void 0;
        };
      })(this);
      ready = (function(_this) {
        return function() {
          console.log("Loaded all resources specified in resources.coffee");
          return _this.trigger("ready");
        };
      })(this);
      return core(function() {
        return preload(function() {
          return resources(function() {
            return postload(function() {
              return ready();
            });
          });
        });
      });
    };

    Resources.prototype.addAndLoad = function(resourceSpecs, callback) {
      var filter, resources;
      resources = this.add(resourceSpecs);
      filter = function(resource) {
        var r, _i, _len;
        for (_i = 0, _len = resources.length; _i < _len; _i++) {
          r = resources[_i];
          if (resource.url === r.url) {
            return true;
          }
        }
        return false;
      };
      this.load(filter, callback);
      return resources;
    };

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
      var resource, resourceLoaded, resources, resourcesToLoad, _i, _len, _results;
      filter = this.filterFunction(filter);
      resources = this.select(function(resource) {
        return !resource.loaded && filter(resource);
      });
      resourcesToLoad = resources.length;
      if (resourcesToLoad === 0) {
        if (typeof loaded === "function") {
          loaded([]);
        }
        return;
      }
      resourceLoaded = (function(_this) {
        return function(resource) {
          resourcesToLoad--;
          if (resourcesToLoad === 0) {
            _this.appendToHead(filter);
            return typeof loaded === "function" ? loaded(resources) : void 0;
          }
        };
      })(this);
      _results = [];
      for (_i = 0, _len = resources.length; _i < _len; _i++) {
        resource = resources[_i];
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

    Resources.prototype.loadFromSpecFile = function(spec) {
      var compile, specFile, url;
      url = spec.url;
      specFile = this.add({
        url: url
      });
      compile = function(code) {
        code = "resources = (obj) -> $blab.resources.processSpec obj\n\n" + code;
        return $coffee.compile(code);
      };
      return this.load((function(resource) {
        return resource.url === url;
      }), (function(_this) {
        return function() {
          specFile.setCompilerSpec({
            compile: compile
          });
          specFile.compile();
          return _this.loadHtmlCss(function() {
            return _this.loadScripts(function() {
              return typeof spec.callback === "function" ? spec.callback() : void 0;
            });
          });
        };
      })(this));
    };

    Resources.prototype.processSpec = function(resources) {
      var url, _i, _len, _ref, _results;
      console.log("----Process files in resources.coffee");
      _ref = resources.load;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        url = _ref[_i];
        if (typeof url === "string" && url.length) {
          _results.push(this.add({
            url: url
          }));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    Resources.prototype.loadHtmlCss = function(callback) {
      return this.load(["html", "css"], (function(_this) {
        return function() {
          return typeof callback === "function" ? callback() : void 0;
        };
      })(this));
    };

    Resources.prototype.loadPackages = function(callback) {
      var filter, loaders;
      loaders = [];
      $blab["package"] = (function(_this) {
        return function(pkg) {
          var load, p, p1, p2, _i, _len;
          p1 = [];
          p2 = [];
          for (_i = 0, _len = pkg.length; _i < _len; _i++) {
            p = pkg[_i];
            if (p.dependent) {
              p2.push(p);
            } else {
              p1.push(p);
            }
          }
          load = function(callback) {
            return _this.addAndLoad(p1, function() {
              return _this.addAndLoad(p2, callback);
            });
          };
          return loaders.push(load);
        };
      })(this);
      filter = function(resource) {
        return resource.loadUrl.indexOf("package.coffee") !== -1;
      };
      return this.load(filter, (function(_this) {
        return function(packages) {
          var coffee, load, n, _i, _j, _len, _len1, _results;
          for (_i = 0, _len = packages.length; _i < _len; _i++) {
            coffee = packages[_i];
            coffee.compile();
          }
          if (loaders.length === 0) {
            if (typeof callback === "function") {
              callback();
            }
            return;
          }
          n = 0;
          _results = [];
          for (_j = 0, _len1 = loaders.length; _j < _len1; _j++) {
            load = loaders[_j];
            n++;
            _results.push(load(function() {
              n--;
              return typeof callback === "function" ? callback() : void 0;
            }));
          }
          return _results;
        };
      })(this));
    };

    Resources.prototype.loadScripts = function(callback) {
      return this.load(["json", "js", "coffee", "py", "m", "svg", "txt"], (function(_this) {
        return function() {
          _this.compileCoffee();
          return typeof callback === "function" ? callback() : void 0;
        };
      })(this));
    };

    Resources.prototype.compileCoffee = function(coffeeFilter) {
      var coffee, filter, _i, _len, _ref, _results;
      filter = function(resource) {
        return resource.isType("coffee") && !(resource.spec.orig.doEval || resource.compiled);
      };
      _ref = this.select(filter);
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        coffee = _ref[_i];
        _results.push(coffee.compile());
      }
      return _results;
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
      var f, resource;
      f = (function(_this) {
        return function(p) {
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
      })(this);
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

    Resources.prototype.sourceMethod = function(getSource) {
      this.getSource = getSource;
    };

    Resources.prototype.on = function(evt, observer) {
      return this.observers[evt].push(observer);
    };

    Resources.prototype.trigger = function(evt, data) {
      var observer, _i, _len, _ref, _results;
      _ref = this.observers[evt];
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        observer = _ref[_i];
        _results.push(observer(data));
      }
      return _results;
    };

    Resources.prototype.triggerAndWait = function(evt, data, cb) {
      var done, n, observer, observers, _i, _len, _results;
      observers = this.observers[evt];
      n = observers.length;
      if (n === 0) {
        cb();
      }
      done = function() {
        n--;
        if (n === 0) {
          return cb();
        }
      };
      _results = [];
      for (_i = 0, _len = observers.length; _i < _len; _i++) {
        observer = observers[_i];
        _results.push(observer(data, done));
      }
      return _results;
    };

    return Resources;

  })();

  window.$pz = {};

  resources = new Resources;

  console.log("$blab", $blab);

  $blab.resources = resources;

  $blab.load = function(r, callback) {
    return resources.addAndLoad(r, callback);
  };

  $blab.loadJSON = (function(_this) {
    return function(url, callback) {
      return resources.loadJSON(url, callback);
    };
  })(this);

  $blab.resource = (function(_this) {
    return function(id) {
      return resources.getContent(id);
    };
  })(this);

  $blab.CoffeeResource = CoffeeResource;

  $blab.precompile = function(pc) {
    return CoffeeResource.registerPrecompileCode(pc);
  };

  resources.init();

  testBlabLocation = function() {
    var loc, r;
    loc = function(url) {
      var b, _ref;
      b = new BlabLocation(url);
      return console.log(b, (_ref = b.gitHub) != null ? _ref.urls() : void 0);
    };
    r = function(url) {
      var z, _ref;
      z = resourceLocation(url);
      return console.log(z, (_ref = z.gitHub) != null ? _ref.urls() : void 0);
    };
    r("http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js");
    r("http://puzlet.org/puzlet/coffee/main.coffee");
    r("/owner/repo/main.coffee");
    r("main.coffee");
    return r("http://api.github.com/repos/owner/repo/contents/path/to/file.ext");
  };

}).call(this);
