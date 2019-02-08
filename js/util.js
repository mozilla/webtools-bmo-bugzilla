/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is the Cross Platform JavaScript Utility Library.
 *
 * The Initial Developer of the Original Code is
 * Everything Solved.
 * Portions created by the Initial Developer are Copyright (C) 2007
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Max Kanat-Alexander <mkanat@bugzilla.org>
 *   Christopher A. Aillon <christopher@aillon.com>
 *
 * ***** END LICENSE BLOCK ***** */

/**
 * Locate where an element is on the page, x-wise.
 *
 * @param  obj Element of which location to return.
 * @return     Current position of the element relative to the left of the
 *             page window. Measured in pixels.
 */
function bz_findPosX(obj)
{
    var curleft = 0;

    if (obj.offsetParent) {
        while (obj) {
            if (getComputedStyle(obj).position != 'relative')
                curleft += obj.offsetLeft;
            obj = obj.offsetParent;
        }
    }
    else if (obj.x) {
        curleft += obj.x;
    }

    return curleft;
}

/**
 * Locate where an element is on the page, y-wise.
 *
 * @param  obj Element of which location to return.
 * @return     Current position of the element relative to the top of the
 *             page window. Measured in pixels.
 */
function bz_findPosY(obj)
{
    var curtop = 0;

    if (obj.offsetParent) {
        while (obj) {
            if (getComputedStyle(obj).position != 'relative')
                curtop += obj.offsetTop;
            obj = obj.offsetParent;
        }
    }
    else if (obj.y) {
        curtop += obj.y;
    }

    return curtop;
}

/**
 * Get the full height of an element, even if it's larger than the browser
 * window.
 *
 * @param  fromObj Element of which height to return.
 * @return         Current height of the element. Measured in pixels.
 */
function bz_getFullHeight(fromObj)
{
    var scrollY;

    // All but Mac IE
    if (fromObj.scrollHeight > fromObj.offsetHeight) {
        scrollY = fromObj.scrollHeight;
    // Mac IE
    }  else {
        scrollY = fromObj.offsetHeight;
    }

    return scrollY;
}

/**
 * Get the full width of an element, even if it's larger than the browser
 * window.
 *
 * @param  fromObj Element of which width to return.
 * @return         Current width of the element. Measured in pixels.
 */
function bz_getFullWidth(fromObj)
{
    var scrollX;

    // All but Mac IE
    if (fromObj.scrollWidth > fromObj.offsetWidth) {
        scrollX = fromObj.scrollWidth;
    // Mac IE
    }  else {
        scrollX = fromObj.offsetWidth;
    }

    return scrollX;
}

/**
 * Causes a block to appear directly underneath another block,
 * overlaying anything below it.
 *
 * @param item   The block that you want to move.
 * @param parent The block that it goes on top of.
 * @return nothing
 */
function bz_overlayBelow(item, parent) {
    var elemY = bz_findPosY(parent);
    var elemX = bz_findPosX(parent);
    var elemH = parent.offsetHeight;

    item.style.position = 'absolute';
    item.style.left = elemX + "px";
    item.style.top = elemY + elemH + 1 + "px";
    item.style.zIndex = 999;
}

/**
 * Checks if a specified value is in the specified array.
 *
 * @param  aArray Array to search for the value.
 * @param  aValue Value to search from the array.
 * @return        Boolean; true if value is found in the array and false if not.
 */
function bz_isValueInArray(aArray, aValue)
{
  for (var run = 0, len = aArray.length ; run < len; run++) {
    if (aArray[run] == aValue) {
      return true;
    }
  }

  return false;
}

/**
 * Checks if a specified value is in the specified array by performing a
 * case-insensitive comparison.
 *
 * @param  aArray Array to search for the value.
 * @param  aValue Value to search from the array.
 * @return        Boolean; true if value is found in the array and false if not.
 */
function bz_isValueInArrayIgnoreCase(aArray, aValue)
{
  var re = new RegExp(aValue.replace(/([^A-Za-z0-9])/g, "\\$1"), 'i');
  for (var run = 0, len = aArray.length ; run < len; run++) {
    if (aArray[run].match(re)) {
      return true;
    }
  }

  return false;
}

/**
 * Create wanted options in a select form control.
 *
 * @param  aSelect        Select form control to manipulate.
 * @param  aValue         Value attribute of the new option element.
 * @param  aTextValue     Value of a text node appended to the new option
 *                        element.
 * @return                Created option element.
 */
function bz_createOptionInSelect(aSelect, aTextValue, aValue) {
  var myOption = new Option(aTextValue, aValue);
  aSelect.options[aSelect.length] = myOption;
  return myOption;
}

/**
 * Clears all options from a select form control.
 *
 * @param  aSelect    Select form control of which options to clear.
 */
function bz_clearOptions(aSelect) {

  var length = aSelect.options.length;

  for (var i = 0; i < length; i++) {
    aSelect.removeChild(aSelect.options[0]);
  }
}

/**
 * Takes an array and moves all the values to an select.
 *
 * @param aSelect         Select form control to populate. Will be cleared
 *                        before array values are created in it.
 * @param aArray          Array with values to populate select with.
 */
function bz_populateSelectFromArray(aSelect, aArray) {
  // Clear the field
  bz_clearOptions(aSelect);

  for (var i = 0; i < aArray.length; i++) {
    var item = aArray[i];
    bz_createOptionInSelect(aSelect, item[1], item[0]);
  }
}

/**
 * Returns all Option elements that are selected in a <select>,
 * as an array. Returns an empty array if nothing is selected.
 *
 * @param aSelect The select you want the selected values of.
 */
function bz_selectedOptions(aSelect) {
    // HTML 5
    if (aSelect.selectedOptions) {
        return aSelect.selectedOptions;
    }

    var start_at = aSelect.selectedIndex;
    if (start_at == -1) return [];
    var first_selected =  aSelect.options[start_at];
    if (!aSelect.multiple) return first_selected;
    // selectedIndex is specified as being the "first selected item",
    // so we can start from there.
    var selected = [first_selected];
    var options_length = aSelect.options.length;
    // We start after first_selected
    for (var i = start_at + 1; i < options_length; i++) {
        var this_option = aSelect.options[i];
        if (this_option.selected) selected.push(this_option);
    }
    return selected;
}

/**
 * Returns all Option elements that have the "selected" attribute, as an array.
 * Returns an empty array if nothing is selected.
 *
 * @param aSelect The select you want the pre-selected values of.
 */
function bz_preselectedOptions(aSelect) {
    var options = aSelect.options;
    var selected = new Array();
    for (var i = 0, l = options.length; i < l; i++) {
        var attributes = options[i].attributes;
        for (var j = 0, m = attributes.length; j < m; j++) {
            if (attributes[j].name == 'selected') {
                if (!aSelect.multiple) return options[i];
                selected.push(options[i]);
            }
        }
    }
    return selected;
}

/**
 * Tells you whether or not a particular value is selected in a select,
 * whether it's a multi-select or a single-select. The check is
 * case-sensitive.
 *
 * @param aSelect        The select you're checking.
 * @param aValue         The value that you want to know about.
 */
function bz_valueSelected(aSelect, aValue) {
    var options = aSelect.options;
    for (var i = 0; i < options.length; i++) {
        if (options[i].selected && options[i].value == aValue) {
            return true;
        }
    }
    return false;
}

/**
 * Tells you where (what index) in a <select> a particular option is.
 * Returns -1 if the value is not in the <select>
 *
 * @param aSelect       The select you're checking.
 * @param aValue        The value you want to know the index of.
 */
function bz_optionIndex(aSelect, aValue) {
    for (var i = 0; i < aSelect.options.length; i++) {
        if (aSelect.options[i].value == aValue) {
            return i;
        }
    }
    return -1;
}

/**
 * Used to fire an event programmatically.
 *
 * @param anElement      The element you want to fire the event of.
 * @param anEvent        The name of the event you want to fire,
 *                       without the word "on" in front of it.
 */
function bz_fireEvent(anElement, anEvent) {
    if (document.createEvent) {
        // DOM-compliant browser
        var evt = document.createEvent("HTMLEvents");
        evt.initEvent(anEvent, true, true);
        return !anElement.dispatchEvent(evt);
    } else {
        // IE
        var evt = document.createEventObject();
        return anElement.fireEvent('on' + anEvent, evt);
    }
}

/**
 * Adds a CSS class to an element if it doesn't have it. Removes the
 * CSS class from the element if the element does have the class.
 *
 * Requires YUI's Dom library.
 *
 * @param anElement  The element to toggle the class on
 * @param aClass     The name of the CSS class to toggle.
 */
function bz_toggleClass(anElement, aClass) {
    if (YAHOO.util.Dom.hasClass(anElement, aClass)) {
        YAHOO.util.Dom.removeClass(anElement, aClass);
    }
    else {
        YAHOO.util.Dom.addClass(anElement, aClass);
    }
}

/* Returns a string representation of a duration.
 *
 * @param ss   Duration in seconds
 * or
 * @param date Date object
 */
function timeAgo(param) {
    var ss = param.constructor === Date ? Math.round((new Date() - param) / 1000) : param;
    var mm = Math.round(ss / 60),
        hh = Math.round(mm / 60),
        dd = Math.round(hh / 24),
        mo = Math.round(dd / 30),
        yy = Math.round(mo / 12);
    if (ss < 10) return 'Just now';
    if (mm < 1) return ss + ' seconds ago';
    if (mm < 2) return '1 minute ago';
    if (hh < 1) return mm + ' minutes ago';
    if (hh < 2) return '1 hour ago';
    if (dd < 1) return hh + ' hours ago';
    if (dd < 2) return '1 day ago';
    if (mo < 1) return dd + ' days ago';
    if (mo < 2) return '1 month ago';
    if (yy < 1) return mo + ' months ago';
    if (yy < 2) return '1 year ago';
    return yy + ' years ago';
}

/**
 * Reference or define the Bugzilla app namespace.
 * @namespace
 */
var Bugzilla = Bugzilla || {}; // eslint-disable-line no-var

/**
 * Enable easier access to the Bugzilla REST API.
 * @hideconstructor
 * @see https://bugzilla.readthedocs.io/en/latest/api/
 */
Bugzilla.API = class API {
  /**
   * Initialize the request settings for `fetch()` or `XMLHttpRequest`.
   * @private
   * @param {String} endpoint See the {@link Bugzilla.API._fetch} method.
   * @param {String} [method='GET'] See the {@link Bugzilla.API._fetch} method.
   * @param {Object} [params] See the {@link Bugzilla.API._fetch} method.
   * @returns {Request} Request settings including the complete URL, HTTP method, headers and body.
   */
  static _init(endpoint, method = 'GET', params = {}) {
    const url = new URL(`${BUGZILLA.config.basepath}rest/${endpoint}`, location.origin);
    const token = BUGZILLA.api_token;

    if (method === 'GET') {
      for (const [key, value] of Object.entries(params)) {
        if (Array.isArray(value)) {
          if (['include_fields', 'exclude_fields'].includes(key)) {
            url.searchParams.set(key, value.join(','));
          } else {
            // Because the REST API v1 doesn't support comma-separated values for certain params, array values have to
            // be appended as duplicated params, so the query string will look like `attachment_ids=1&attachment_ids=2`
            // instead of `attachment_ids=1,2`.
            value.forEach(val => url.searchParams.append(key, val));
          }
        } else {
          url.searchParams.set(key, value);
        }
      }
    }

    /** @todo Remove this once Bug 1477163 is solved */
    if (token) {
      url.searchParams.set('Bugzilla_api_token', token);
    }

    return new Request(url, {
      method,
      body: method !== 'GET' ? JSON.stringify(params) : null,
      credentials: 'same-origin',
      cache: 'no-cache',
    });
  }

  /**
   * Send a `fetch()` request to a Bugzilla REST API endpoint and return results.
   * @private
   * @param {String} endpoint URL path excluding the `/rest/` prefix; may also contain query parameters.
   * @param {Object} [options] Request options.
   * @param {String} [options.method='GET'] HTTP request method. POST, GET, PUT, etc.
   * @param {Object} [options.params] Request parameters. For a GET request, it will be sent as the URL query params.
   * The values will be automatically URL-encoded, so don't use `encodeURIComponent()` for each. For a non-GET request,
   * this will be part of the request body. The params can be included in `endpoint` if those are simple (no encoding
   * required) or if the request is not GET but URL query params are required.
   * @param {Object} [options.init] Extra options for the `fetch()` method.
   * @returns {Promise.<(Object|Array.<Object>|Error)>} Response data for a valid response, or an `Error` object for an
   * error returned from the REST API as well as any other exception including an aborted or failed HTTP request.
   * @see https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/fetch
   */
  static async _fetch(endpoint, { method = 'GET', params = {}, init = {} } = {}) {
    const request = this._init(endpoint, method, params);

    if (!navigator.onLine) {
      return Promise.reject(new Bugzilla.Error({ name: 'OfflineError', message: 'You are currently offline.' }));
    }

    return new Promise((resolve, reject) => {
      const timer = window.setTimeout(() => {
        reject(new Bugzilla.Error({ name: 'TimeoutError', message: 'Request Timeout' }));
      }, 30000);

      /** @throws {AbortError} */
      fetch(request, init).then(response => {
        /** @throws {SyntaxError} */
        return response.ok ? response.json() : { error: true };
      }).then(result => {
        const { error, code, message } = result;

        if (error) {
          reject(new Bugzilla.Error({ name: 'APIError', code, message }));
        } else {
          resolve(result);
        }
      }).catch(({ name, code, message }) => {
        reject(new Bugzilla.Error({ name, code, detail: message }));
      });

      window.clearTimeout(timer);
    });
  }

  /**
   * Shorthand for a GET request with the {@link Bugzilla.API._fetch} method.
   * @param {String} endpoint See the {@link Bugzilla.API._fetch} method.
   * @param {Object} [params] See the {@link Bugzilla.API._fetch} method.
   * @param {Object} [init] See the {@link Bugzilla.API._fetch} method.
   * @returns {Promise.<(Object|Array.<Object>|Error)>} See the {@link Bugzilla.API._fetch} method.
   */
  static async get(endpoint, params = {}, init = {}) {
    return this._fetch(endpoint, { method: 'GET', params, init });
  }

  /**
   * Shorthand for a POST request with the {@link Bugzilla.API._fetch} method.
   * @param {String} endpoint See the {@link Bugzilla.API._fetch} method.
   * @param {Object} [params] See the {@link Bugzilla.API._fetch} method.
   * @param {Object} [init] See the {@link Bugzilla.API._fetch} method.
   * @returns {Promise.<(Object|Array.<Object>|Error)>} See the {@link Bugzilla.API._fetch} method.
   */
  static async post(endpoint, params = {}, init = {}) {
    return this._fetch(endpoint, { method: 'POST', params, init });
  }

  /**
   * Shorthand for a PUT request with the {@link Bugzilla.API._fetch} method.
   * @param {String} endpoint See the {@link Bugzilla.API._fetch} method.
   * @param {Object} [params] See the {@link Bugzilla.API._fetch} method.
   * @param {Object} [init] See the {@link Bugzilla.API._fetch} method.
   * @returns {Promise.<(Object|Array.<Object>|Error)>} See the {@link Bugzilla.API._fetch} method.
   */
  static async put(endpoint, params = {}, init = {}) {
    return this._fetch(endpoint, { method: 'PUT', params, init });
  }

  /**
   * Shorthand for a PATCH request with the {@link Bugzilla.API._fetch} method.
   * @param {String} endpoint See the {@link Bugzilla.API._fetch} method.
   * @param {Object} [params] See the {@link Bugzilla.API._fetch} method.
   * @param {Object} [init] See the {@link Bugzilla.API._fetch} method.
   * @returns {Promise.<(Object|Array.<Object>|Error)>} See the {@link Bugzilla.API._fetch} method.
   */
  static async patch(endpoint, params = {}, init = {}) {
    return this._fetch(endpoint, { method: 'PATCH', params, init });
  }

  /**
   * Shorthand for a DELETE request with the {@link Bugzilla.API._fetch} method.
   * @param {String} endpoint See the {@link Bugzilla.API._fetch} method.
   * @param {Object} [params] See the {@link Bugzilla.API._fetch} method.
   * @param {Object} [init] See the {@link Bugzilla.API._fetch} method.
   * @returns {Promise.<(Object|Array.<Object>|Error)>} See the {@link Bugzilla.API._fetch} method.
   */
  static async delete(endpoint, params = {}, init = {}) {
    return this._fetch(endpoint, { method: 'DELETE', params, init });
  }

  /**
   * Success callback function for the {@link Bugzilla.API.xhr} method.
   * @callback Bugzilla.API~resolve
   * @param {Object|Array.<Object>} data Response data for a valid response.
   */

  /**
   * Error callback function for the {@link Bugzilla.API.xhr} method.
   * @callback Bugzilla.API~reject
   * @param {Error} error `Error` object providing a reason. See the {@link Bugzilla.Error} for details.
   */

  /**
   * Make an `XMLHttpRequest` to a Bugzilla REST API endpoint and return results. This is useful when you need more
   * control than `fetch()`, particularly to upload a file while monitoring the progress.
   * @param {String} endpoint See the {@link Bugzilla.API._fetch} method.
   * @param {Object} [options] Request options.
   * @param {String} [options.method='GET'] See the {@link Bugzilla.API._fetch} method.
   * @param {Object} [options.params] See the {@link Bugzilla.API._fetch} method.
   * @param {Bugzilla.API~resolve} [options.resolve] Callback function for a valid response.
   * @param {Bugzilla.API~reject} [options.reject] Callback function for an error returned from the REST API as well as
   * any other exception including an aborted or failed HTTP request.
   * @param {Object.<String, Function>} [options.download] Raw event listeners for download; the key is an event type
   * such as `load` or `error`, the value is an event listener.
   * @param {Object.<String, Function>} [options.upload] Raw event listeners for upload; the key is an event type such
   * as `progress` or `error`, the value is an event listener.
   * @returns {XMLHttpRequest} Request.
   * @see https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest/Using_XMLHttpRequest#Monitoring_progress
   */
  static xhr(endpoint, { method = 'GET', params = {}, resolve, reject, download, upload } = {}) {
    const xhr = new XMLHttpRequest();
    const { url, headers, body } = this._init(endpoint, method, params);

    resolve = typeof resolve === 'function' ? resolve : () => {};
    reject = typeof reject === 'function' ? reject : () => {};

    if (!navigator.onLine) {
      reject(new Bugzilla.Error({ name: 'OfflineError', message: 'You are currently offline.' }));

      return xhr;
    }

    xhr.addEventListener('load', () => {
      try {
        /** @throws {SyntaxError} */
        const result = JSON.parse(xhr.responseText);
        const { error, code, message } = result;

        if (parseInt(xhr.status / 100) !== 2 || error) {
          reject(new Bugzilla.Error({ name: 'APIError', code, message }));
        } else {
          resolve(result);
        }
      } catch ({ name, code, message }) {
        reject(new Bugzilla.Error({ name, code, detail: message }));
      }
    });

    xhr.addEventListener('abort', () => {
      reject(new Bugzilla.Error({ name: 'AbortError' }));
    });

    xhr.addEventListener('error', () => {
      reject(new Bugzilla.Error({ name: 'NetworkError' }));
    });

    xhr.addEventListener('timeout', () => {
      reject(new Bugzilla.Error({ name: 'TimeoutError', message: 'Request Timeout' }));
    });

    for (const [type, handler] of Object.entries(download || {})) {
      xhr.addEventListener(type, event => handler(event));
    }

    for (const [type, handler] of Object.entries(upload || {})) {
      xhr.upload.addEventListener(type, event => handler(event));
    }

    xhr.open(method, url);

    for (const [key, value] of headers) {
      xhr.setRequestHeader(key, value);
    }

    // Set timeout in 30 seconds given some large results
    xhr.timeout = 30000;

    xhr.send(body);

    return xhr;
  }
};

/**
 * Extend the generic `Error` class so it can contain a custom name and other data if needed. This allows to gracefully
 * handle an error from either the REST API or the browser.
 */
Bugzilla.Error = class CustomError extends Error {
  /**
   * Initialize the `CustomError` object.
   * @param {Object} [options] Error options.
   * @param {String} [options.name='Error'] Distinguishable error name that can be taken from an original `DOMException`
   * object if any, e.g. `AbortError` or `SyntaxError`.
   * @param {String} [options.message='Unexpected Error'] Localizable, user-friendly message probably from the REST API.
   * @param {Number} [options.code=0] Custom error code from the REST API or `DOMException` code.
   * @param {String} [options.detail] Detailed, technical message probably from an original `DOMException` that end
   * users don't have to see.
   */
  constructor({ name = 'Error', message = 'Unexpected Error', code = 0, detail } = {}) {
    super(message);
    this.name = name;
    this.code = code;
    this.detail = detail;

    console.error(this.toString());
  }

  /**
   * Define the string representation of the error object.
   * @override
   * @returns {String} Custom string representation.
   */
  toString() {
    return `${this.name}: "${this.message}" (code: ${this.code}${this.detail ? `, detail: ${this.detail}` : ''})`;
  }
};

/**
 * Provide static utility methods related to the local storage.
 */
Bugzilla.Storage = class Storage {
  /**
   * Try to get a cache from the local storage.
   * @param {String} key Cache key.
   * @param {Boolean} [session_only=false] Whether the cache is stored only during the current session.
   * @returns {*} Cached data if available.
   */
  static get(key, session_only = false) {
    const storage = session_only ? sessionStorage : localStorage;

    try {
      const cache = storage.getItem(key);

      if (!cache) {
        return null;
      }

      const { data, expires } = JSON.parse(cache);

      if (!expires || expires > Date.now()) {
        return data;
      }

      // Remove expired cache
      storage.removeItem(key);
    } catch (ex) {}

    return null;
  }

  /**
   * Try to save a cache to the local storage.
   * @param {String} key Cache key.
   * @param {*} data Data to be cached.
   * @param {Number} [life=0] Storage lifetime. Default: unlimited.
   * @param {Boolean} [session_only=false] Whether the cache is stored only during the current session.
   */
  static save(key, data, life = 0, session_only = false) {
    const storage = session_only ? sessionStorage : localStorage;

    try {
      storage.setItem(key, JSON.stringify({ data, expires: life ? Date.now() + life : 0 }));
    } catch (ex) {}
  }
};

/**
 * Provide static utility methods related to UI localization.
 * @todo Add plural support.
 */
Bugzilla.L10n = class L10n {
  /**
   * Get a global string by key while replacing a placeholder.
   * @param {String} key Key to find the string.
   * @param {String} [replacer] Placeholder replacement.
   * @returns {String} Formatted string.
   */
  static get(key, replacer = '') {
    return BUGZILLA.string[key].replace('%s', replacer);
  }
};

/**
 * Provide static utility methods related to array parsing and manipulation.
 */
Bugzilla.Array = class Array {
  /**
   * Sort an array of objects using a given property.
   * @param {Object[]} array Array to be sorted.
   * @param {String} key Object property to be used as a sort key.
   * @param {Boolean} [descending] Whether the order is descending rather than ascending.
   * @returns {Array} Sorted array.
   * @todo Add support for several data types.
   */
  static sort(array, key, { descending = false } = {}) {
    array.sort((a, b) => (a[key] > b[key] ? 1 : a[key] < b[key] ? -1 : 0));

    return descending ? array.reverse() : array;
  }
};

/**
 * Provide static utility methods related to string parsing and manipulation.
 */
Bugzilla.String = class String {
  /**
   * Check if all words are contained in the given string.
   * @param {String} string Original string to be searched.
   * @param {(String|String[])} words Search terms, may contain spaces.
   * @param {Boolean} [ignore_case] Whether to do a case insensitive match.
   * @param {Boolean} [find_all] Whether all the words should be contained in the string.
   * @param {Boolean} [match_boundaries] Whether the matching should consider word boundaries. This needs to be
   * `false` for languages like Japanese where there's no space between words.
   * @returns {Boolean} Whether the words could be found in the string.
   */
  static find(string, words, { ignore_case = true, find_all = true, match_boundaries = true } = {}) {
    words = Array.isArray(words) ? words : words.split(/\s+/);

    const finder = word => {
      // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Regular_Expressions#Escaping
      const escaped_word = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const re = new RegExp(`${match_boundaries ? '\\b' : ''}${escaped_word}`, ignore_case ? 'i' : '');

      return !!string.match(re);
    };

    return find_all ? words.every(finder) : words.some(finder);
  }

  /**
   * Highlight words in a string with HTML `<strong>` elements.
   * @param {String} string Original string that may contain these words.
   * @param {(String|String[])} words Words to be highlighted.
   * @param {Boolean} [ignore_case] Whether to do a case insensitive match.
   * @returns {String} Highlighted HTML string.
   */
  static highlight(string, words, { ignore_case = true } = {}) {
    words = Array.isArray(words) ? words : words.split(/\s+/);

    const _string = ignore_case ? string.toLocaleLowerCase() : string;
    const _words = ignore_case ? words.map(word => word.toLocaleLowerCase()) : words;
    const matched = new Set(); // Allow to discard duplicates unlike Array

    for (const word of _words) {
      for (let i = 0; i < _string.length; i++) {
        const index = _string.indexOf(word, i);

        if (index === -1) {
          break;
        }

        // Log the index and move the cursor forward
        for (i = index; i < index + word.length; i++) {
          matched.add(i);
        }
      }
    }

    return [...string].map((char, index) => {
      char = char.htmlEncode();

      return matched.has(index) ? `<strong>${char}</strong>` : char;
    }).join('').replace(/<\/strong><strong>/g, '');
  }
};
