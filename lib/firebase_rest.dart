// Copyright (c) 2015, Rik Bellens. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// A firebase REST library.
library firebase;

import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';

abstract class _Reference {
  final Uri _url;
  final String _auth;

  _Reference._(this._url, this._auth);

  Uri get _fullUrl;

  /**
   * Gets the value at this Firebase location.
   */
  Future<DataSnapshot> get() async {
    http.Response v = await http.get(_fullUrl);
    if (v.statusCode != 200) {
      throw new Exception(JSON.decode(v.body)["error"]);
    }
    return new DataSnapshot._(this, JSON.decode(v.body));
  }

  Query _addQueryParameter(String key, String value) {
    return new Query._(_url, auth: _auth)
      .._query = (new Map.from(this is Query
          ? (this as Query)._query
          : {"orderBy": JSON.encode(r"$key")})..[key] = value);
  }

  /**
   * Generates a new [Query] object ordered by the specified child key.
   */
  Query orderByChild(String child) {
    //TODO: fallback when no index
    if (child == null || child.startsWith(r"$"))
      throw new ArgumentError("'$child' is not a valid child");

    return _addQueryParameter("orderBy", JSON.encode(child));
  }

  /**
   * Generates a new [Query] object ordered by key.
   */
  Query orderByKey() => _addQueryParameter("orderBy", JSON.encode(r"$key"));

  /**
   * Generates a new [Query] object ordered by child values.
   */
  Query orderByValue() => _addQueryParameter("orderBy", JSON.encode(r"$value"));

  /**
   * Generates a new [Query] object ordered by priority.
   */
  Query orderByPriority() =>
      _addQueryParameter("orderBy", JSON.encode(r"$priority"));

  /**
   * Creates a [Query] with the specified starting point.
   * The generated Query includes children which match the specified starting
   * point.
   */
  Query startAt(dynamic value) =>
      _addQueryParameter("startAt", JSON.encode(value));

  /**
   * Creates a [Query] with the specified ending point.
   * The generated Query includes children which match the specified ending
   * point.
   */
  Query endAt(dynamic value) => _addQueryParameter("endAt", JSON.encode(value));

  /**
   * Creates a [Query] which includes children which match the specified value.
   */
  Query equalTo(dynamic value) =>
      _addQueryParameter("equalTo", JSON.encode(value));

  /**
   * Generates a new [Query] object limited to the first certain number of
   * children.
   */
  Query limitToFirst(int limit) => _addQueryParameter("limitToFirst", "$limit");

  /**
   * Generates a new [Query] object limited to the last certain number of
   * children.
   */
  Query limitToLast(int limit) => _addQueryParameter("limitToLast", "$limit");
}

/**
 * A Query sorts and filters the data at a database location so only a subset
 * of the child data is included.
 * This can be used to order a collection of data by some attribute (e.g.
 * height of dinosaurs) as well as to
 * restrict a large list of items (e.g. chat messages) down to a number suitable
 * for synchronizing to the client.
 * Queries are created by chaining together one or more of the filter functions
 * defined below.
 */
class Query extends _Reference {
  Map<String, String> _query = {};

  Query._(Uri url, {String auth})
      : super._(url.path.endsWith("/") ? url : Uri.parse("$url/"), auth);

  Firebase get ref => new Firebase(_url, auth: _auth);

  Map<String, String> get _queryParameters {
    var r = new Map<String, String>.from(_query);
    if (_auth != null) r["auth"] = _auth;
    return r;
  }

  Uri get _fullUrl {
    var url = _url.resolve(".json");
    url = url.replace(queryParameters: _queryParameters);
    return url;
  }
}


class Event {
  final String prevChild;
  final DataSnapshot snapshot;

  const Event(this.snapshot, this.prevChild);
}

/**
 * A Firebase reference represents a particular location in your database and
 * can be used for reading or writing data
 * to that database location.
 */
class Firebase extends _Reference {
  /**
   * Constructs a new Firebase reference from a full Firebase URL.
   *
   * The [auth] token is either the Firebase Database secret, or a JWT
   * token signed with that secret. 
   * It is comparable with the JavaScript function
   * [Firebase.authWithCustomToken](https://www.firebase.com/docs/web/api/firebase/authwithcustomtoken.html)
   */
  Firebase(Uri url, {String auth})
      : super._(url.path.endsWith("/") ? url : Uri.parse("$url/"), auth);

  /**
   * Returns this Firebase location.
   */
  Uri get url => _url;

  /**
   * Returns a Firebase reference for the location at the specified relative
   * path.
   */
  Firebase child(String c) => new Firebase(_url.resolve(c), auth: _auth);

  /**
   * Returns a Firebase reference to the parent location.
   */
  Firebase get parent => new Firebase(_parentUri(_url), auth: _auth);

  /**
   * Returns a Firebase reference to the root of the Firebase.
   */
  Firebase get root => new Firebase(_rootUri(_url), auth: _auth);

  /**
   * Returns the last token in a Firebase location.
   */
  String get key => _url.pathSegments.isEmpty ? null : _url.pathSegments.lastWhere((s)=>s.isNotEmpty);

  Uri get _fullUrl {
    var url = _url.resolve(".json");
    if (_auth != null) url = url.replace(queryParameters: {"auth": _auth});
    return url;
  }

  /**
   * Writes data to this Firebase location.
   *
   * [value] is the data to be written to your Firebase (can be a [Map], [List],
   * [String], [num], [bool], or [null]).
   * Passing null will remove the data at the specified location.
   */
  Future set(dynamic value) async {
    if (value == null) {
      await http.delete(_fullUrl);
    } else {
      var response = await http.put(_fullUrl, body: JSON.encode(value));
      if (response.statusCode != 200) {
        throw new Exception(JSON.decode(response.body)["error"]);
      }
    }
  }

  /**
   * Writes the enumerated children to this Firebase location. Setting
   * a key's value to `null` will remove the value.
   */
  Future update(Map<String, dynamic> value) async {
    if (value == null) {
      await http.delete(_fullUrl);
    } else {
      var response = await _patch(_fullUrl, JSON.encode(value));
      if (response.statusCode != 200) {
        throw new Exception(JSON.decode(response.body)["error"]);
      }
    }
  }

  Future _patch(Uri url, String body) {
    var client = new http.Client();

    var request = new http.Request("PATCH", url);
    request.body = body;

    var future = client.send(request);

    return future.whenComplete(client.close);
  }

  /**
   * Removes the data at this Firebase location.
   */
  Future remove() => set(null);

  /**
   * Generates a new child location using a unique key and returns a Firebase
   * reference to it.
   */
  Future<Firebase> push(dynamic value) async {
    var response = await http.post(_fullUrl, body: JSON.encode(value));
    if (response.statusCode != 200) {
      throw new Exception(JSON.decode(response.body)["error"]);
    }
    return child(JSON.decode(response.body)["name"]);
  }

  static Uri _parentUri(Uri uri) => uri.resolve("..").normalizePath();

  static Uri _rootUri(Uri uri) => uri.resolve("/").normalizePath();



  Stream<Event> _onValue;
  Stream<Event> get onValue => _onValue = _onValue ?? _createOnValueStream();


  Stream<Event> _createOnValueStream() {

    var controller = new StreamController();

    _FirebaseSubscription s;
    var stream = controller.stream.asBroadcastStream(
        onListen: (subscription) {
          s = new _FirebaseSubscription(this);
          controller.addStream(s.stream.map((s)=>new Event(s,null)));
        },
        onCancel: (subscription) => s.close()
    );
    return new _Property.fromStream(stream);
  }
}

/**
 * A [DataSnapshot] contains data from a Firebase database location.
 * Any time you read data from a Firebase database, you receive the data as a
 * DataSnapshot.
 */
class DataSnapshot {
  dynamic _val;
  _Reference _ref;

  DataSnapshot._(this._ref, this._val);

  /**
   * Returns the Dart object representation of the DataSnapshot.
   */
  dynamic get val => _val;

  /**
   * Returns true if this DataSnapshot contains any data.
   */
  bool get exists => _val != null;

  /**
   * Gets the Firebase reference for the location that generated this
   * DataSnapshot.
   */
  _Reference get ref => _ref;

  _get(List<String> path) {
    var o = _val;
    for (var p in path) {
      if (o is !Map||!o.containsKey(p)) return null;
      o = o[p];
    }
    return o;
  }
  DataSnapshot _put(String path, value) {
    var parts = path.split("/").sublist(1);
    if (parts.isNotEmpty&&parts.last.isEmpty) parts = parts.sublist(0, parts.length - 1);
    var oldValue = _get(parts);
    if (_equals(value,oldValue))
      return this;
    if (parts.isEmpty) return new DataSnapshot._(_ref, value);
    var val = JSON.decode(JSON.encode(_val)) ?? {};
    var snapshot = new DataSnapshot._(_ref, val);
    for (var p in parts.sublist(0, parts.length - 1)) {
      val = (val as Map).putIfAbsent(p, () => {});
    }
    val[parts.last] = value;
    return snapshot;
  }

  _equals(a,b) => a==b||(a is Map&&b is Map&&const MapEquality().equals(a,b));

  DataSnapshot _patch(String path, Map value) {
    var parts = path.split("/").sublist(1);
    if (parts.isNotEmpty&&parts.last.isEmpty) parts = parts.sublist(0, parts.length - 1);
    var oldValue = _get(parts);
    if (oldValue is Map) {
      if (value.keys.every((k) => _equals(value[k], oldValue[k])))
        return this;
    }

    var val = JSON.decode(JSON.encode(_val));
    var snapshot = new DataSnapshot._(_ref, val);
    for (var p in parts) {
      val = (val as Map).putIfAbsent(p, () => {});
    }
    for (var k in value.keys) {
      val[k] = value[k];
    }
    return snapshot;
  }
}

class _FirebaseSubscription {
  _EventSource _source;

  DataSnapshot _current;

  final Firebase ref;
  StreamController<DataSnapshot> _controller;

  Stream<DataSnapshot> get stream => _controller.stream.distinct();
  StreamSubscription _subscription;
  DateTime _lastEventTime;

  close() {
    _controller.close();
    _source.close();
  }

  _openEventSourceDelayed() {
    new Future.delayed(new Duration(seconds: 5))
        .then((_)=>_openEventSource());
  }
  _openEventSource() async {
    _source = new _EventSource(ref.url.toString(), auth: ref._auth);

    _subscription = _source.stream.listen((evt) {
      _lastEventTime = new DateTime.now();
      new Future.delayed(new Duration(seconds: 45))
          .then((_) {
        if (new DateTime.now().difference(_lastEventTime)>new Duration(seconds: 35)) {
          _subscription.cancel();
          _openEventSource();
        }
      });
      switch (evt.type) {
        case "put":
          var data = JSON.decode(evt.data);
          _current = _current._put(data["path"], data["data"]);
          break;
        case "patch":
          var data = JSON.decode(evt.data);
          _current = _current._patch(data["path"], data["data"]);
          break;
        case "keep-alive":
          return;
        default:
          return;
      }
      _controller.add(_current);
    }, onError: (_)=>_openEventSourceDelayed());


  }

  _FirebaseSubscription(this.ref) {
    _current = new DataSnapshot._(ref, null);

    _controller = new StreamController.broadcast(
        onListen: _openEventSource, onCancel: () {
      _subscription.cancel();
    });
  }
}

class _Event {
  final String data;
  final String type;

  _Event._(this.type, this.data);

  toString() => "$type $data";
}

class _EventSource {
  final Uri url;
  final String auth;

  http.StreamedResponse _response;
  http.Client _client;

  StreamController<_Event> _controller;

  _EventSource(String url, {bool withCredentials: false, this.auth})
      : this.url = Uri.parse(url) {

    _controller = new StreamController(
        onListen: _open,
        onCancel: close
    );
  }

  Future _open() async {
    var request = new http.Request("GET", url.resolve(".json")
        .replace(queryParameters: auth!=null ? {"auth": auth} : const {}));
    request.headers["Accept"] = "text/event-stream";
    _client = new http.Client();

    try {
      _response = await _client.send(request);
    } catch (e) {
      _controller.addError(e);
      return;
    }

    var mData, mType;

    await _response.stream
        .transform(UTF8.decoder)
        .transform(new LineSplitter())
        .forEach((String data) {
      if (_controller.isClosed) return;
      if (data.isEmpty) {
        if (data != null) {
          _controller.add(new _Event._(mType, mData));
          mType = null;
          mData = null;
        }
      } else if (mType == null && mData == null && data.startsWith("event: ")) {
        mType = data.substring("event: ".length);
      } else if (mData == null && data.startsWith("data: ")) {
        mData = data.substring("data: ".length);
      } else if (mData != null) {
        mData = "$mData\n$data";
      } else {
        throw new Exception("Invalid value $data");
      }
    });


    if (!_isClosed) {
      _open();
    }

  }

  bool _isClosed = false;
  void close() {
    _isClosed = true;
    _client.close();
  }

  Stream<_Event> get stream => _controller.stream;
}


class _Property<T> extends Stream<T> {
  StreamController _controller;
  bool _hasCurrentValue = false;
  T _currentValue;

  _Property._(Stream<T> stream, bool hasInitialValue, [T initialValue]) {
    _hasCurrentValue = hasInitialValue;
    _currentValue = initialValue;
    _controller = _createControllerForStream(stream);
  }
  /// Returns a new property where its current value is the latest value emitted
  /// from [stream].
  factory _Property.fromStream(Stream<T> stream) => new _Property._(stream, false);

  StreamSubscription<T> listen(void onData(T value), {Function onError, void onDone(), bool cancelOnError}) {
    var controller = new StreamController(sync: true);

    if (_hasCurrentValue) {
      controller.add(_currentValue);
    }

    controller.addStream(_controller.stream, cancelOnError: false).then((_) => controller.close());

    return controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
  StreamController _createControllerForStream(Stream stream) {
    var input = stream;
    StreamSubscription subscription;

    void onListen() {
      if (subscription == null) {
        subscription = input.listen(
            (value) {
          _currentValue = value;
          _hasCurrentValue = true;
          _controller.add(value);
        },
            onError: _controller.addError,
            onDone: () {
              _controller.close();
            });
      }
    }

    void onCancel() {
      subscription.cancel();
      subscription = null;
    }

    return new StreamController.broadcast(onListen: onListen, onCancel: onCancel, sync: true);
  }

}