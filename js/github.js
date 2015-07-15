// Generated by CoffeeScript 1.7.1
(function() {
  var CredentialsForm, Gist, GitHub, Repo, SaveButton, dependencies, _ref, _ref1;

  console.log("GitHub/Gist");

  dependencies = [
    {
      url: "//ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/themes/smoothness/jquery-ui.css"
    }, {
      url: "//ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/jquery-ui.min.js"
    }, {
      url: "/puzlet/puzlet/css/github.css"
    }, {
      url: "/puzlet/puzlet/js/jquery.cookie.js"
    }
  ];

  if (typeof $blab !== "undefined" && $blab !== null) {
    if ((_ref = $blab.resources) != null) {
      _ref.on("preload", function(data, done) {
        return $blab.load(dependencies, function() {
          return new GitHub($blab.resources, done);
        });
      });
    }
  }

  if (typeof $blab !== "undefined" && $blab !== null) {
    if ((_ref1 = $blab.resources) != null) {
      _ref1.on("ready", function() {
        var container;
        container = $(".github-save");
        if (container.length) {
          return new SaveButton(container, function() {
            return $.event.trigger("saveGitHub");
          });
        }
      });
    }
  }

  GitHub = (function() {
    function GitHub(resources, callback) {
      this.resources = resources;
      this.setCredentials();
      this.gist = new Gist({
        resources: this.resources,
        getUsername: (function(_this) {
          return function() {
            if (_this.auth) {
              return _this.username;
            } else {
              return null;
            }
          };
        })(this),
        authBeforeSend: (function(_this) {
          return function(xhr) {
            return _this.authBeforeSend(xhr);
          };
        })(this),
        callback: callback
      });
      this.repo = new Repo({
        resources: this.resources,
        getUsername: (function(_this) {
          return function() {
            if (_this.auth) {
              return _this.username;
            } else {
              return null;
            }
          };
        })(this),
        authBeforeSend: (function(_this) {
          return function(xhr) {
            return _this.authBeforeSend(xhr);
          };
        })(this)
      });
      this.sourceLink();
      this.saveAsNewButton();
      $(document).on("saveGitHub", (function(_this) {
        return function() {
          $.event.trigger("preSaveResources");
          return _this.save();
        };
      })(this));
    }

    GitHub.prototype.save = function(forceNew, callback) {
      if (forceNew == null) {
        forceNew = false;
      }
      if (this.credentialsForm) {
        this.credentialsForm.open();
        return;
      }
      return this.credentialsForm = new CredentialsForm({
        setCredentials: (function(_this) {
          return function(username, key) {
            return _this.setCredentials(username, key);
          };
        })(this),
        isRepoMember: (function(_this) {
          return function(cb) {
            return _this.repo.isRepoMember(cb);
          };
        })(this),
        updateRepo: (function(_this) {
          return function(callback) {
            return _this.repo.commitChangedResourcesToRepo(callback);
          };
        })(this),
        saveAsGist: (function(_this) {
          return function(callback) {
            return _this.gist.save(forceNew, callback);
          };
        })(this)
      });
    };

    GitHub.prototype.setCredentials = function(username, key) {
      var make_base_auth;
      this.username = username;
      this.key = key;
      make_base_auth = function(user, password) {
        var hash, tok;
        tok = user + ':' + password;
        hash = btoa(tok);
        return "Basic " + hash;
      };
      if (this.username && this.key) {
        return this.auth = make_base_auth(this.username, this.key);
      }
    };

    GitHub.prototype.authBeforeSend = function(xhr) {
      if (!this.auth) {
        return;
      }
      console.log("Set request header", this.auth);
      return xhr.setRequestHeader('Authorization', this.auth);
    };

    GitHub.prototype.sourceLink = function() {
      var id, link;
      id = this.gist.id;
      if (!id) {
        return;
      }
      link = $("#github-source-link");
      if (link.length) {
        return link.html("<a href='//gist.github.com/" + id + "' target='_blank'>GitHub source</a>");
      }
    };

    GitHub.prototype.saveAsNewButton = function() {
      var button, div;
      div = $("#github-save-as-new-button");
      if (!div.length) {
        return;
      }
      button = $("<button>", {
        text: "Save as new Gist",
        click: (function(_this) {
          return function() {
            var forceNew;
            forceNew = true;
            return _this.save(forceNew);
          };
        })(this)
      });
      return div.append(button);
    };

    return GitHub;

  })();

  Gist = (function() {
    Gist.prototype.api = "https://api.github.com/gists";

    function Gist(spec) {
      var _ref2;
      this.spec = spec;
      _ref2 = this.spec, this.resources = _ref2.resources, this.getUsername = _ref2.getUsername, this.authBeforeSend = _ref2.authBeforeSend, this.callback = _ref2.callback;
      this.id = this.getId();
      this.apiId = (function(_this) {
        return function() {
          return "" + _this.api + "/" + _this.id;
        };
      })(this);
      this.gistQuery = (function(_this) {
        return function() {
          return "?" + _this.id;
        };
      })(this);
      this.load(this.callback);
    }

    Gist.prototype.load = function(callback) {
      if (!this.id) {
        this.data = null;
        if (typeof callback === "function") {
          callback();
        }
        return;
      }
      return $.get(this.apiId(), (function(_this) {
        return function(data) {
          var _ref2;
          _this.data = data;
          console.log("Gist loaded", _this.data);
          _this.gistOwner = (_ref2 = _this.data.owner) != null ? _ref2.login : void 0;
          _this.resources.sourceMethod(function(url) {
            var _ref3, _ref4, _ref5;
            return (_ref3 = (_ref4 = _this.data.files) != null ? (_ref5 = _ref4[url]) != null ? _ref5.content : void 0 : void 0) != null ? _ref3 : null;
          });
          return typeof callback === "function" ? callback() : void 0;
        };
      })(this));
    };

    Gist.prototype.save = function(forceNew, callback) {
      var content, resource, resources, _i, _len, _ref2;
      if (forceNew == null) {
        forceNew = false;
      }
      this.username = this.getUsername();
      console.log("Save as Gist (" + ((_ref2 = this.username) != null ? _ref2 : 'anonymous') + ")");
      resources = this.resources.select(function(resource) {
        return resource.inBlab() && resource.url !== "resources.coffee";
      });
      this.files = {};
      for (_i = 0, _len = resources.length; _i < _len; _i++) {
        resource = resources[_i];
        content = resource.content;
        if (content && content !== "\n") {
          this.files[resource.url] = {
            content: content
          };
        }
      }
      if (this.id && this.username && !forceNew) {
        if (this.username === this.gistOwner) {
          return this.edit(callback);
        } else {
          return this.forkAndEdit();
        }
      } else {
        return this.create();
      }
    };

    Gist.prototype.ajaxData = function() {
      var ajaxData, ajaxDataObj;
      ajaxDataObj = {
        description: this.description(),
        "public": false,
        files: this.files
      };
      return ajaxData = JSON.stringify(ajaxDataObj);
    };

    Gist.prototype.create = function() {
      return $.ajax({
        type: "POST",
        url: this.api,
        data: this.ajaxData(),
        beforeSend: (function(_this) {
          return function(xhr) {
            return _this.authBeforeSend(xhr);
          };
        })(this),
        success: (function(_this) {
          return function(data) {
            console.log("Created Gist", data);
            _this.id = data.id;
            if (_this.username) {
              return _this.setDescription(function() {
                return _this.redirect();
              });
            } else {
              return _this.redirect();
            }
          };
        })(this),
        dataType: "json"
      });
    };

    Gist.prototype.forkAndEdit = function() {
      console.log("Fork...");
      return this.fork((function(_this) {
        return function(data) {
          _this.id = data.id;
          return _this.patch(_this.ajaxData(), (function() {
            return _this.redirect();
          }));
        };
      })(this));
    };

    Gist.prototype.edit = function(callback) {
      return this.patch(this.ajaxData(), (function(_this) {
        return function() {
          var resource, _i, _len, _ref2;
          _ref2 = _this.resources;
          for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
            resource = _ref2[_i];
            resource.edited = false;
          }
          if (typeof callback === "function") {
            callback();
          }
          return $.event.trigger("codeSaved");
        };
      })(this));
    };

    Gist.prototype.patch = function(ajaxData, callback) {
      return $.ajax({
        type: "PATCH",
        url: this.apiId(),
        data: ajaxData,
        beforeSend: (function(_this) {
          return function(xhr) {
            return _this.authBeforeSend(xhr);
          };
        })(this),
        success: function(data) {
          console.log("Updated Gist", data);
          return typeof callback === "function" ? callback() : void 0;
        },
        dataType: "json"
      });
    };

    Gist.prototype.fork = function(callback) {
      console.log("FORK", this.apiId());
      return $.ajax({
        type: "POST",
        url: "" + (this.apiId()) + "/forks",
        beforeSend: (function(_this) {
          return function(xhr) {
            return _this.authBeforeSend(xhr);
          };
        })(this),
        success: (function(_this) {
          return function(data) {
            console.log("Forked Gist", data);
            return typeof callback === "function" ? callback(data) : void 0;
          };
        })(this),
        dataType: "json"
      });
    };

    Gist.prototype.setDescription = function(callback) {
      var ajaxData;
      ajaxData = JSON.stringify({
        description: this.description()
      });
      return this.patch(ajaxData, callback);
    };

    Gist.prototype.description = function() {
      var description;
      description = document.title;
      if (this.id) {
        description += " [" + (this.blabUrl()) + "]";
      }
      return description;
    };

    Gist.prototype.redirect = function() {
      return window.location = this.blabUrl();
    };

    Gist.prototype.blabUrl = function() {
      var l, p, pathname;
      l = window.location;
      p = l.pathname.split("/");
      pathname = p.slice(-1).join("/");
      return [l.protocol, '//', l.host, pathname, this.gistQuery()].join('');
    };

    Gist.prototype.getId = function() {
      var h, p, _ref2;
      this.a = document.createElement("a");
      this.a.href = window.location.href;
      this.search = this.a.search;
      this.query = (_ref2 = this.search) != null ? _ref2.slice(1) : void 0;
      if (!this.query) {
        return null;
      }
      h = this.query.split("&");
      p = h != null ? h[0].split("=") : void 0;
      if (p.length && p[0] === "gist") {
        return p[1];
      } else {
        return p[0];
      }
    };

    return Gist;

  })();

  Repo = (function() {
    Repo.prototype.ghApi = "https://api.github.com/repos/puzlet";

    Repo.prototype.ghMembersApi = "https://api.github.com/orgs/puzlet/members";

    function Repo(spec) {
      var _ref2, _ref3, _ref4;
      this.spec = spec;
      _ref2 = this.spec, this.resources = _ref2.resources, this.getUsername = _ref2.getUsername, this.authBeforeSend = _ref2.authBeforeSend;
      this.blabLocation = this.resources.blabLocation;
      this.hostname = (_ref3 = this.blabLocation) != null ? _ref3.host : void 0;
      this.blabId = (_ref4 = this.blabLocation) != null ? _ref4.repo : void 0;
    }

    Repo.prototype.repoApiUrl = function(path) {
      return "" + this.ghApi + "/" + this.blabId + "/contents/" + path;
    };

    Repo.prototype.commitChangedResourcesToRepo = function(callback) {
      var commit, maxIdx, resources;
      if (!(this.hostname === "puzlet.org" || this.hostname === "localhost" && this.username && this.key)) {
        console.log("Can commit changes only to puzlet.org repo, and only with credentials.");
        return;
      }
      resources = this.resources.select(function(resource) {
        return resource.edited;
      });
      console.log("resources", resources);
      if (!resources.length) {
        return;
      }
      maxIdx = resources.length - 1;
      commit = (function(_this) {
        return function(idx) {
          var resource;
          if (idx > maxIdx) {
            if (typeof callback === "function") {
              callback();
            }
            $.event.trigger("codeSaved");
            return;
          }
          resource = resources[idx];
          return _this.loadResourceFromRepo(resource, function(data) {
            resource.sha = data.sha;
            return _this.commitResourceToRepo(resource, function() {
              resource.edited = false;
              return commit(idx + 1);
            });
          });
        };
      })(this);
      return commit(0);
    };

    Repo.prototype.loadResourceFromRepo = function(resource, callback) {
      var path, url;
      path = resource.url;
      url = this.repoApiUrl(path);
      return $.get(url, (function(_this) {
        return function(data) {
          console.log("Loaded resource " + path + " from repo", data);
          return typeof callback === "function" ? callback(data) : void 0;
        };
      })(this));
    };

    Repo.prototype.commitResourceToRepo = function(resource, callback) {
      var ajaxData, path, url;
      path = resource.url;
      url = this.repoApiUrl(path);
      ajaxData = {
        message: "Puzlet commit",
        path: path,
        content: btoa(resource.content),
        sha: resource.sha
      };
      return $.ajax({
        type: "PUT",
        url: url,
        data: JSON.stringify(ajaxData),
        beforeSend: (function(_this) {
          return function(xhr) {
            return _this.authBeforeSend(xhr);
          };
        })(this),
        success: (function(_this) {
          return function(data) {
            console.log("Updated repo file", data);
            return typeof callback === "function" ? callback(data) : void 0;
          };
        })(this),
        dataType: "json"
      });
    };

    Repo.prototype.getRepoMembers = function(callback) {
      return $.ajax({
        type: "GET",
        url: this.ghMembersApi,
        beforeSend: (function(_this) {
          return function(xhr) {
            return _this.authBeforeSend(xhr);
          };
        })(this),
        success: function(data) {
          return typeof callback === "function" ? callback(data) : void 0;
        },
        dataType: "json"
      });
    };

    Repo.prototype.isRepoMember = function(callback) {
      var found, set;
      if (this.cacheIsRepoMember == null) {
        this.cacheIsRepoMember = {};
      }
      if (this.cacheIsRepoMember[this.username] != null) {
        callback(this.cacheIsRepoMember[this.username]);
      }
      set = (function(_this) {
        return function(isMember) {
          if (_this.username) {
            _this.cacheIsRepoMember[_this.username] = isMember;
          }
          return callback(isMember);
        };
      })(this);
      if (!(this.blabId && this.username && this.key)) {
        set(false);
        return;
      }
      found = false;
      this.getRepoMembers((function(_this) {
        return function(members) {
          var member, _i, _len;
          for (_i = 0, _len = members.length; _i < _len; _i++) {
            member = members[_i];
            found = _this.username === member.login;
            if (found) {
              set(true);
              return;
            }
          }
        };
      })(this));
      return set(false);
    };

    return Repo;

  })();

  CredentialsForm = (function() {
    function CredentialsForm(spec) {
      this.spec = spec;
      this.username = $.cookie("gh_user");
      this.key = $.cookie("gh_key");
      this.dialog = $("<div>", {
        id: "github_save_dialog",
        title: "Save immediately, or enter credentials."
      });
      this.dialog.dialog({
        autoOpen: false,
        height: 500,
        width: 500,
        modal: true,
        close: (function(_this) {
          return function() {
            return _this.form[0].reset();
          };
        })(this)
      });
      this.spec.setCredentials(this.username, this.key);
      this.setButtons();
      this.form = $("<form>", {
        id: "github_save_form",
        submit: (function(_this) {
          return function(evt) {
            return evt.preventDefault();
          };
        })(this)
      });
      this.dialog.append(this.form);
      this.usernameField();
      this.keyField();
      this.infoText();
      this.saving = $("<p>", {
        text: "Saving...",
        css: {
          fontSize: "16pt",
          color: "green"
        }
      });
      this.dialog.append(this.saving);
      this.saving.hide();
      this.open();
    }

    CredentialsForm.prototype.open = function() {
      this.usernameInput.val(this.username);
      this.keyInput.val(this.key);
      this.setButtons();
      return this.dialog.dialog("open");
    };

    CredentialsForm.prototype.usernameField = function() {
      var id, label;
      id = "username";
      label = $("<label>", {
        "for": id,
        text: "Username"
      });
      this.usernameInput = $("<input>", {
        name: "username",
        id: id,
        value: this.username,
        "class": "text ui-widget-content ui-corner-all",
        change: (function(_this) {
          return function() {
            return _this.setCredentials();
          };
        })(this)
      });
      return this.form.append(label).append(this.usernameInput);
    };

    CredentialsForm.prototype.keyField = function() {
      var id, label;
      id = "key";
      label = $("<label>", {
        "for": id,
        text: "Personal access token"
      });
      this.keyInput = $("<input>", {
        type: "password",
        name: "key",
        id: id,
        value: this.key,
        "class": "text ui-widget-content ui-corner-all",
        change: (function(_this) {
          return function() {
            return _this.setCredentials();
          };
        })(this)
      });
      return this.form.append(label).append(this.keyInput);
    };

    CredentialsForm.prototype.infoText = function() {
      return this.dialog.append("<br>\n<p>To save under your GitHub account, enter your GitHub username and personal access token.\nYou can generate your personal access token <a href='https://github.com/settings/applications' target='_blank'>here</a>.\n</p>\n<p>\nTo save as <i>anonymous</i> Gist, continue without credentials.\n</p>\n<p>\nYour GitHub username and personal access token will be saved as cookies for future saves.\nTo remove these cookies, clear the credentials above.\n</p>");
    };

    CredentialsForm.prototype.setCredentials = function() {
      console.log("Setting credentials and updating cookies");
      this.username = this.usernameInput.val() !== "" ? this.usernameInput.val() : null;
      this.key = this.keyInput.val() !== "" ? this.keyInput.val() : null;
      $.cookie("gh_user", this.username);
      $.cookie("gh_key", this.key);
      this.spec.setCredentials(this.username, this.key);
      return this.setButtons();
    };

    CredentialsForm.prototype.setButtons = function() {
      var buttons, done, saveAction, sel, _base;
      saveAction = (function(_this) {
        return function() {
          _this.setCredentials();
          return _this.saving.show();
        };
      })(this);
      done = (function(_this) {
        return function() {
          _this.saving.hide();
          _this.form[0].reset();
          return _this.dialog.dialog("close");
        };
      })(this);
      buttons = {
        "Update repo": (function(_this) {
          return function() {
            saveAction();
            return _this.spec.updateRepo(function() {
              return done();
            });
          };
        })(this),
        "Save as Gist": (function(_this) {
          return function() {
            saveAction();
            return _this.spec.saveAsGist(function() {
              return done();
            });
          };
        })(this),
        Cancel: (function(_this) {
          return function() {
            return _this.dialog.dialog("close");
          };
        })(this)
      };
      sel = function(n) {
        var idx, o, p, v;
        o = {};
        idx = 0;
        for (p in buttons) {
          v = buttons[p];
          if (idx >= n) {
            o[p] = v;
          }
          idx++;
        }
        return o;
      };
      this.dialog.dialog({
        buttons: sel(1)
      });
      return typeof (_base = this.spec).isRepoMember === "function" ? _base.isRepoMember((function(_this) {
        return function(isMember) {
          if (isMember) {
            return _this.dialog.dialog({
              buttons: sel(0)
            });
          }
        };
      })(this)) : void 0;
    };

    return CredentialsForm;

  })();

  SaveButton = (function() {
    function SaveButton(container, callback) {
      var _base;
      this.container = container;
      this.callback = callback;
      this.div = $("<div>", {
        id: "save_button_container",
        css: {
          position: "fixed",
          top: 10,
          right: 10
        }
      });
      this.b = $("<button>", {
        text: "Save",
        click: (function(_this) {
          return function() {
            var _base;
            if (typeof (_base = _this.b).hide === "function") {
              _base.hide();
            }
            return typeof _this.callback === "function" ? _this.callback() : void 0;
          };
        })(this),
        title: "When you're done editing, save your changes to GitHub."
      });
      this.savingMessage = $("<span>", {
        css: {
          top: 20,
          color: "#2a2",
          cursor: "default"
        },
        text: "Saving..."
      });
      this.div.append(this.b).append(this.savingMessage);
      this.container.append(this.div);
      this.b.hide();
      this.savingMessage.hide();
      this.firstChange = true;
      $(document).on("codeNodeChanged", (function(_this) {
        return function() {
          var before;
          before = function() {
            return "*** UNSAVED CHANGES ***";
          };
          $(document).on("saveGitHub", function() {
            return before = function() {
              return null;
            };
          });
          if (_this.firstChange) {
            $(window).on("beforeunload", function() {
              return before();
            });
            _this.firstChange = false;
          }
          return _this.b.show();
        };
      })(this));
      if (typeof (_base = this.b).button === "function") {
        _base.button({
          label: "Save"
        });
      }
    }

    SaveButton.prototype.saving = function() {
      this.b.hide();
      return this.savingMessage.show();
    };

    return SaveButton;

  })();

}).call(this);
