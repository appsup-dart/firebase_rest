// Copyright (c) 2015, Rik Bellens. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// A firebase REST library.
library firebase;

import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
   * Generates a new [Query] object limited to the last certain number of children.
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

/**
 * A Firebase reference represents a particular location in your database and
 * can be used for reading or writing data
 * to that database location.
 */
class Firebase extends _Reference {
  /**
   * Constructs a new Firebase reference from a full Firebase URL.
   *
   * If [auth] is defined, it will be used as authentication token in requests.
   * Auth must be a "Firebase Database Secret", which can be generated
   * by the Firebase Admin Console.
   */
  Firebase(Uri url, {String auth})
      : super._(url.path.endsWith("/") ? url : Uri.parse("$url/"), auth);

  /**
   * Returns this Firebase location.
   */
  Uri get url => _url;

  /**
   * Returns a Firebase reference for the location at the specified relative path.
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
  String get key => _url.pathSegments.isEmpty ? null : _url.pathSegments.last;

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

  DataSnapshot _put(String path, value) {
    var val = JSON.decode(JSON.encode(_val));
    var snapshot = new DataSnapshot._(_ref, val);
    var parts = path.split("/").sublist(1);
    if (parts.last.isEmpty) parts = parts.sublist(0, parts.length - 1);
    for (var p in parts.sublist(0, parts.length - 1)) {
      val = (val as Map).putIfAbsent(p, () => {});
    }
    val[parts.last] = value;
    return snapshot;
  }

  DataSnapshot _patch(String path, Map value) {
    var val = JSON.decode(JSON.encode(_val));
    var snapshot = new DataSnapshot._(_ref, val);
    var parts = path.split("/").sublist(1);
    if (parts.last.isEmpty) parts = parts.sublist(0, parts.length - 1);
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

  StreamController<DataSnapshot> _controller = new StreamController.broadcast();

  Stream<DataSnapshot> get stream => _controller.stream;

  _FirebaseSubscription(Firebase ref) {
    _source = new _EventSource(ref.url.toString());

    _source.stream.listen((evt) {
      switch (evt.type) {
        case "put":
          var data = JSON.decode(evt.data);

          if (data["path"] == "/") {
            _current = new DataSnapshot._(ref, data["data"]);
          } else {
            _current = _current._put(data["path"], data["data"]);
          }
          break;
        case "patch":
          var data = JSON.decode(evt.data);
          _current = _current._patch(data["path"], data["data"]);
          break;
        default:
          return;
      }

      _controller.add(_current);
    });
  }
}

class _Event {
  final String data;
  final String type;

  _Event._(this.type, this.data);
}

class _EventSource {
  final Uri url;

  http.StreamedResponse _response;
  http.Client _client;

  StreamController<_Event> _controller = new StreamController.broadcast();

  _EventSource(String url, {bool withCredentials: false})
      : this.url = Uri.parse(url) {
    _open();
  }

  Future _open() async {
    var request = new http.Request("GET", url.resolve(".json"));
    request.headers["Accept"] = "text/event-stream";
    _client = new http.Client();

    _response = await _client.send(request);

    var mData, mType;
    _response.stream
        .transform(UTF8.decoder)
        .transform(new LineSplitter())
        .listen((String data) {
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
  }

  void close() {
    _client.close();
  }

  Stream<_Event> get stream => _controller.stream;
}
