Forked from [stackp/promisejs](https://github.com/stackp/promisejs/tree/2ac90b7c04cf3095d58659649b98d66a3e5ad2f2).

# promise.js

A lightweight javascript implementation of promises.

## Using the `Promise` Object

Promises provide an alternative to callback-passing. Asynchronous functions return a `Promise` object onto which callbacks can be attached.

Callbacks are attached using the `.then(callback)` method. They will be called when the promise is resolved.

```js
var p = asyncfoo(a, b, c);

p.then(function(error, result) {
    if (error) return;
    alert(result);
});
```

Asynchronous functions must resolve the promise with the `.done()` method when their task is done. This invokes the promise callback(s) with the same arguments that were passed to `.done()`.

```js
function asyncfoo() {

    var p = new promise.Promise();  /* (1) create a Promise */

    setTimeout(function() {
        p.done(null, "O hai!");     /* (3) resolve it when ready */
    }, 1000);

    return p;                       /* (2) return it */
}
```

## A Word on Callback Signatures

Although an arbitrary number of arguments are accepted for callbacks, the following signature is recommended: `callback(error, result)`.

The `error` parameter can be used to pass an error code such that `error != false` in case something went wrong; the `result` parameter is used to pass a value produced by the asynchronous task. This allows to write callbacks like this:

```js
function callback(error, result) {
    if (error) {
        /* Deal with error case. */
        ...
        return;
    }
       
    /* Deal with normal case. */
    ...
}
```

## Chaining Asynchronous Functions

There are two ways of chaining asynchronous function calls. The first one is to make the callback return a promise object and to chain `.then()` calls. Indeed, `.then()` returns a `Promise` that is resolved when the callback resolves its promise.

**Example:**

```js
function late(n) {
    var p = new promise.Promise();
    setTimeout(function() {
        p.done(null, n);
    }, n);
    return p;
}

late(100).then(
    function(err, n) {
        return late(n + 200);
    }
).then(
    function(err, n) {
        return late(n + 300);
    }
).then(
    function(err, n) {
        return late(n + 400);
    }
).then(
    function(err, n) {
        alert(n);
    }
);
```

The other option is to use `promise.chain()`. The function expects an array of asynchronous functions that return a promise each. `promise.chain()` itself returns a `Promise`.

```js
promise.chain([f1, f2, f3, ...]);
```

**Example:**

```js
function late(n) {
    var p = new promise.Promise();
    setTimeout(function() {
        p.done(null, n);
    }, n);
    return p;
}

promise.chain([
    function() {
        return late(100);
    },
    function(err, n) {
        return late(n + 200);
    },
    function(err, n) {
        return late(n + 300);
    },
    function(err, n) {
        return late(n + 400);
    }
]).then(
    function(err, n) {
        alert(n);
    }
);
```

## Joining Functions

    promise.join([p1, p2, p3, ...]);

`promise.join()` expects an array of `Promise` object and returns a `Promise` that will be resolved once all the arguments have been resolved. The callback will be passed an array containing the values passed by each promise, in the same order that the promises were given. 

**Example**:

```js
function late(n) {
    var p = new promise.Promise();
    setTimeout(function() {
        p.done(null, n);
    }, n);
    return p;
}

promise.join([
    late(400),
    late(800)
]).then(
    function(results) {
        var res0 = results[0];
        var res1 = results[1];
        alert(res0[1] + " " + res1[1]);
    }
);
```

## AJAX Functions Included

Because AJAX requests are the root of much asynchrony in Javascript, promise.js provides the following functions:

```js
promise.get(url, data, headers)
promise.post(url, data, headers)
promise.put(url, data, headers)
promise.del(url, data, headers)
```

`data` *(optional)* : a {key: value} object or url-encoded string.

`headers` *(optional)* :  a {key: value} object (e.g. `{"Accept": "application/json"}`).

**Example**:

```js
promise.get('/').then(function(error, text, xhr) {
    if (error) {
        alert('Error ' + xhr.status);
        return;
    }
    alert('The page contains ' + text.length + ' character(s).');
});
```

You can set a time in milliseconds after which unresponsive AJAX
requests should be aborted. This is a global configuration option,
disabled by default.

    /* Global configuration option */
    promise.ajaxTimeout = 10000;


## Browser compatibility

The library has been successfully tested on IE5.5+ and FF1.5+


Have fun!
