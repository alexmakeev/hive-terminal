// This is a generated file - do not edit.
//
// Generated from hive.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'hive.pb.dart' as $0;

export 'hive.pb.dart';

/// Authentication service
@$pb.GrpcServiceName('hive.Auth')
class AuthClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AuthClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.AuthResponse> validateApiKey(
    $0.ApiKeyRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$validateApiKey, request, options: options);
  }

  // method descriptors

  static final _$validateApiKey =
      $grpc.ClientMethod<$0.ApiKeyRequest, $0.AuthResponse>(
          '/hive.Auth/ValidateApiKey',
          ($0.ApiKeyRequest value) => value.writeToBuffer(),
          $0.AuthResponse.fromBuffer);
}

@$pb.GrpcServiceName('hive.Auth')
abstract class AuthServiceBase extends $grpc.Service {
  $core.String get $name => 'hive.Auth';

  AuthServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ApiKeyRequest, $0.AuthResponse>(
        'ValidateApiKey',
        validateApiKey_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ApiKeyRequest.fromBuffer(value),
        ($0.AuthResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.AuthResponse> validateApiKey_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ApiKeyRequest> $request) async {
    return validateApiKey($call, await $request);
  }

  $async.Future<$0.AuthResponse> validateApiKey(
      $grpc.ServiceCall call, $0.ApiKeyRequest request);
}

/// SSH Key management
@$pb.GrpcServiceName('hive.Keys')
class KeysClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  KeysClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.KeyListResponse> list(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$list, request, options: options);
  }

  $grpc.ResponseFuture<$0.Key> create(
    $0.CreateKeyRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$create, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> delete(
    $0.DeleteKeyRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$delete, request, options: options);
  }

  // method descriptors

  static final _$list = $grpc.ClientMethod<$0.Empty, $0.KeyListResponse>(
      '/hive.Keys/List',
      ($0.Empty value) => value.writeToBuffer(),
      $0.KeyListResponse.fromBuffer);
  static final _$create = $grpc.ClientMethod<$0.CreateKeyRequest, $0.Key>(
      '/hive.Keys/Create',
      ($0.CreateKeyRequest value) => value.writeToBuffer(),
      $0.Key.fromBuffer);
  static final _$delete = $grpc.ClientMethod<$0.DeleteKeyRequest, $0.Empty>(
      '/hive.Keys/Delete',
      ($0.DeleteKeyRequest value) => value.writeToBuffer(),
      $0.Empty.fromBuffer);
}

@$pb.GrpcServiceName('hive.Keys')
abstract class KeysServiceBase extends $grpc.Service {
  $core.String get $name => 'hive.Keys';

  KeysServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.KeyListResponse>(
        'List',
        list_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.KeyListResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CreateKeyRequest, $0.Key>(
        'Create',
        create_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateKeyRequest.fromBuffer(value),
        ($0.Key value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteKeyRequest, $0.Empty>(
        'Delete',
        delete_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DeleteKeyRequest.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
  }

  $async.Future<$0.KeyListResponse> list_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return list($call, await $request);
  }

  $async.Future<$0.KeyListResponse> list(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.Key> create_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateKeyRequest> $request) async {
    return create($call, await $request);
  }

  $async.Future<$0.Key> create(
      $grpc.ServiceCall call, $0.CreateKeyRequest request);

  $async.Future<$0.Empty> delete_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteKeyRequest> $request) async {
    return delete($call, await $request);
  }

  $async.Future<$0.Empty> delete(
      $grpc.ServiceCall call, $0.DeleteKeyRequest request);
}

/// Connection configuration management
@$pb.GrpcServiceName('hive.Connections')
class ConnectionsClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  ConnectionsClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.ConnectionListResponse> list(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$list, request, options: options);
  }

  $grpc.ResponseFuture<$0.Connection> create(
    $0.CreateConnectionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$create, request, options: options);
  }

  $grpc.ResponseFuture<$0.Connection> update(
    $0.UpdateConnectionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$update, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> delete(
    $0.DeleteConnectionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$delete, request, options: options);
  }

  // method descriptors

  static final _$list = $grpc.ClientMethod<$0.Empty, $0.ConnectionListResponse>(
      '/hive.Connections/List',
      ($0.Empty value) => value.writeToBuffer(),
      $0.ConnectionListResponse.fromBuffer);
  static final _$create =
      $grpc.ClientMethod<$0.CreateConnectionRequest, $0.Connection>(
          '/hive.Connections/Create',
          ($0.CreateConnectionRequest value) => value.writeToBuffer(),
          $0.Connection.fromBuffer);
  static final _$update =
      $grpc.ClientMethod<$0.UpdateConnectionRequest, $0.Connection>(
          '/hive.Connections/Update',
          ($0.UpdateConnectionRequest value) => value.writeToBuffer(),
          $0.Connection.fromBuffer);
  static final _$delete =
      $grpc.ClientMethod<$0.DeleteConnectionRequest, $0.Empty>(
          '/hive.Connections/Delete',
          ($0.DeleteConnectionRequest value) => value.writeToBuffer(),
          $0.Empty.fromBuffer);
}

@$pb.GrpcServiceName('hive.Connections')
abstract class ConnectionsServiceBase extends $grpc.Service {
  $core.String get $name => 'hive.Connections';

  ConnectionsServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.ConnectionListResponse>(
        'List',
        list_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.ConnectionListResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CreateConnectionRequest, $0.Connection>(
        'Create',
        create_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreateConnectionRequest.fromBuffer(value),
        ($0.Connection value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateConnectionRequest, $0.Connection>(
        'Update',
        update_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateConnectionRequest.fromBuffer(value),
        ($0.Connection value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteConnectionRequest, $0.Empty>(
        'Delete',
        delete_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteConnectionRequest.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
  }

  $async.Future<$0.ConnectionListResponse> list_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return list($call, await $request);
  }

  $async.Future<$0.ConnectionListResponse> list(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.Connection> create_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateConnectionRequest> $request) async {
    return create($call, await $request);
  }

  $async.Future<$0.Connection> create(
      $grpc.ServiceCall call, $0.CreateConnectionRequest request);

  $async.Future<$0.Connection> update_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateConnectionRequest> $request) async {
    return update($call, await $request);
  }

  $async.Future<$0.Connection> update(
      $grpc.ServiceCall call, $0.UpdateConnectionRequest request);

  $async.Future<$0.Empty> delete_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteConnectionRequest> $request) async {
    return delete($call, await $request);
  }

  $async.Future<$0.Empty> delete(
      $grpc.ServiceCall call, $0.DeleteConnectionRequest request);
}

/// Session management
@$pb.GrpcServiceName('hive.Sessions')
class SessionsClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  SessionsClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.SessionListResponse> list(
    $0.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$list, request, options: options);
  }

  $grpc.ResponseFuture<$0.Session> create(
    $0.CreateSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$create, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> close(
    $0.CloseSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$close, request, options: options);
  }

  // method descriptors

  static final _$list = $grpc.ClientMethod<$0.Empty, $0.SessionListResponse>(
      '/hive.Sessions/List',
      ($0.Empty value) => value.writeToBuffer(),
      $0.SessionListResponse.fromBuffer);
  static final _$create =
      $grpc.ClientMethod<$0.CreateSessionRequest, $0.Session>(
          '/hive.Sessions/Create',
          ($0.CreateSessionRequest value) => value.writeToBuffer(),
          $0.Session.fromBuffer);
  static final _$close = $grpc.ClientMethod<$0.CloseSessionRequest, $0.Empty>(
      '/hive.Sessions/Close',
      ($0.CloseSessionRequest value) => value.writeToBuffer(),
      $0.Empty.fromBuffer);
}

@$pb.GrpcServiceName('hive.Sessions')
abstract class SessionsServiceBase extends $grpc.Service {
  $core.String get $name => 'hive.Sessions';

  SessionsServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Empty, $0.SessionListResponse>(
        'List',
        list_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Empty.fromBuffer(value),
        ($0.SessionListResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CreateSessionRequest, $0.Session>(
        'Create',
        create_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreateSessionRequest.fromBuffer(value),
        ($0.Session value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CloseSessionRequest, $0.Empty>(
        'Close',
        close_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CloseSessionRequest.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
  }

  $async.Future<$0.SessionListResponse> list_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Empty> $request) async {
    return list($call, await $request);
  }

  $async.Future<$0.SessionListResponse> list(
      $grpc.ServiceCall call, $0.Empty request);

  $async.Future<$0.Session> create_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateSessionRequest> $request) async {
    return create($call, await $request);
  }

  $async.Future<$0.Session> create(
      $grpc.ServiceCall call, $0.CreateSessionRequest request);

  $async.Future<$0.Empty> close_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CloseSessionRequest> $request) async {
    return close($call, await $request);
  }

  $async.Future<$0.Empty> close(
      $grpc.ServiceCall call, $0.CloseSessionRequest request);
}

/// Terminal I/O (bidirectional streaming)
@$pb.GrpcServiceName('hive.Terminal')
class TerminalClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  TerminalClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseStream<$0.TerminalOutput> attach(
    $async.Stream<$0.TerminalInput> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$attach, request, options: options);
  }

  // method descriptors

  static final _$attach =
      $grpc.ClientMethod<$0.TerminalInput, $0.TerminalOutput>(
          '/hive.Terminal/Attach',
          ($0.TerminalInput value) => value.writeToBuffer(),
          $0.TerminalOutput.fromBuffer);
}

@$pb.GrpcServiceName('hive.Terminal')
abstract class TerminalServiceBase extends $grpc.Service {
  $core.String get $name => 'hive.Terminal';

  TerminalServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.TerminalInput, $0.TerminalOutput>(
        'Attach',
        attach,
        true,
        true,
        ($core.List<$core.int> value) => $0.TerminalInput.fromBuffer(value),
        ($0.TerminalOutput value) => value.writeToBuffer()));
  }

  $async.Stream<$0.TerminalOutput> attach(
      $grpc.ServiceCall call, $async.Stream<$0.TerminalInput> request);
}
