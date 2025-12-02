// This is a generated file - do not edit.
//
// Generated from hive.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use emptyDescriptor instead')
const Empty$json = {
  '1': 'Empty',
};

/// Descriptor for `Empty`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emptyDescriptor =
    $convert.base64Decode('CgVFbXB0eQ==');

@$core.Deprecated('Use apiKeyRequestDescriptor instead')
const ApiKeyRequest$json = {
  '1': 'ApiKeyRequest',
  '2': [
    {'1': 'api_key', '3': 1, '4': 1, '5': 9, '10': 'apiKey'},
  ],
};

/// Descriptor for `ApiKeyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List apiKeyRequestDescriptor = $convert
    .base64Decode('Cg1BcGlLZXlSZXF1ZXN0EhcKB2FwaV9rZXkYASABKAlSBmFwaUtleQ==');

@$core.Deprecated('Use authResponseDescriptor instead')
const AuthResponse$json = {
  '1': 'AuthResponse',
  '2': [
    {'1': 'valid', '3': 1, '4': 1, '5': 8, '10': 'valid'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'username', '3': 3, '4': 1, '5': 9, '10': 'username'},
  ],
};

/// Descriptor for `AuthResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List authResponseDescriptor = $convert.base64Decode(
    'CgxBdXRoUmVzcG9uc2USFAoFdmFsaWQYASABKAhSBXZhbGlkEhcKB3VzZXJfaWQYAiABKAlSBn'
    'VzZXJJZBIaCgh1c2VybmFtZRgDIAEoCVIIdXNlcm5hbWU=');

@$core.Deprecated('Use keyDescriptor instead')
const Key$json = {
  '1': 'Key',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'public_key', '3': 3, '4': 1, '5': 9, '10': 'publicKey'},
    {'1': 'created_at', '3': 4, '4': 1, '5': 9, '10': 'createdAt'},
  ],
};

/// Descriptor for `Key`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyDescriptor = $convert.base64Decode(
    'CgNLZXkSDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSHQoKcHVibGljX2tleR'
    'gDIAEoCVIJcHVibGljS2V5Eh0KCmNyZWF0ZWRfYXQYBCABKAlSCWNyZWF0ZWRBdA==');

@$core.Deprecated('Use keyListResponseDescriptor instead')
const KeyListResponse$json = {
  '1': 'KeyListResponse',
  '2': [
    {'1': 'keys', '3': 1, '4': 3, '5': 11, '6': '.hive.Key', '10': 'keys'},
  ],
};

/// Descriptor for `KeyListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyListResponseDescriptor = $convert.base64Decode(
    'Cg9LZXlMaXN0UmVzcG9uc2USHQoEa2V5cxgBIAMoCzIJLmhpdmUuS2V5UgRrZXlz');

@$core.Deprecated('Use createKeyRequestDescriptor instead')
const CreateKeyRequest$json = {
  '1': 'CreateKeyRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'private_key', '3': 2, '4': 1, '5': 9, '10': 'privateKey'},
    {'1': 'public_key', '3': 3, '4': 1, '5': 9, '10': 'publicKey'},
  ],
};

/// Descriptor for `CreateKeyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createKeyRequestDescriptor = $convert.base64Decode(
    'ChBDcmVhdGVLZXlSZXF1ZXN0EhIKBG5hbWUYASABKAlSBG5hbWUSHwoLcHJpdmF0ZV9rZXkYAi'
    'ABKAlSCnByaXZhdGVLZXkSHQoKcHVibGljX2tleRgDIAEoCVIJcHVibGljS2V5');

@$core.Deprecated('Use deleteKeyRequestDescriptor instead')
const DeleteKeyRequest$json = {
  '1': 'DeleteKeyRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteKeyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteKeyRequestDescriptor =
    $convert.base64Decode('ChBEZWxldGVLZXlSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use connectionDescriptor instead')
const Connection$json = {
  '1': 'Connection',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'host', '3': 3, '4': 1, '5': 9, '10': 'host'},
    {'1': 'port', '3': 4, '4': 1, '5': 5, '10': 'port'},
    {'1': 'username', '3': 5, '4': 1, '5': 9, '10': 'username'},
    {'1': 'ssh_key_id', '3': 6, '4': 1, '5': 9, '10': 'sshKeyId'},
    {'1': 'startup_command', '3': 7, '4': 1, '5': 9, '10': 'startupCommand'},
    {'1': 'created_at', '3': 8, '4': 1, '5': 9, '10': 'createdAt'},
  ],
};

/// Descriptor for `Connection`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectionDescriptor = $convert.base64Decode(
    'CgpDb25uZWN0aW9uEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEhIKBGhvc3'
    'QYAyABKAlSBGhvc3QSEgoEcG9ydBgEIAEoBVIEcG9ydBIaCgh1c2VybmFtZRgFIAEoCVIIdXNl'
    'cm5hbWUSHAoKc3NoX2tleV9pZBgGIAEoCVIIc3NoS2V5SWQSJwoPc3RhcnR1cF9jb21tYW5kGA'
    'cgASgJUg5zdGFydHVwQ29tbWFuZBIdCgpjcmVhdGVkX2F0GAggASgJUgljcmVhdGVkQXQ=');

@$core.Deprecated('Use connectionListResponseDescriptor instead')
const ConnectionListResponse$json = {
  '1': 'ConnectionListResponse',
  '2': [
    {
      '1': 'connections',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.hive.Connection',
      '10': 'connections'
    },
  ],
};

/// Descriptor for `ConnectionListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectionListResponseDescriptor =
    $convert.base64Decode(
        'ChZDb25uZWN0aW9uTGlzdFJlc3BvbnNlEjIKC2Nvbm5lY3Rpb25zGAEgAygLMhAuaGl2ZS5Db2'
        '5uZWN0aW9uUgtjb25uZWN0aW9ucw==');

@$core.Deprecated('Use createConnectionRequestDescriptor instead')
const CreateConnectionRequest$json = {
  '1': 'CreateConnectionRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'host', '3': 2, '4': 1, '5': 9, '10': 'host'},
    {'1': 'port', '3': 3, '4': 1, '5': 5, '10': 'port'},
    {'1': 'username', '3': 4, '4': 1, '5': 9, '10': 'username'},
    {'1': 'ssh_key_id', '3': 5, '4': 1, '5': 9, '10': 'sshKeyId'},
    {'1': 'startup_command', '3': 6, '4': 1, '5': 9, '10': 'startupCommand'},
  ],
};

/// Descriptor for `CreateConnectionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createConnectionRequestDescriptor = $convert.base64Decode(
    'ChdDcmVhdGVDb25uZWN0aW9uUmVxdWVzdBISCgRuYW1lGAEgASgJUgRuYW1lEhIKBGhvc3QYAi'
    'ABKAlSBGhvc3QSEgoEcG9ydBgDIAEoBVIEcG9ydBIaCgh1c2VybmFtZRgEIAEoCVIIdXNlcm5h'
    'bWUSHAoKc3NoX2tleV9pZBgFIAEoCVIIc3NoS2V5SWQSJwoPc3RhcnR1cF9jb21tYW5kGAYgAS'
    'gJUg5zdGFydHVwQ29tbWFuZA==');

@$core.Deprecated('Use updateConnectionRequestDescriptor instead')
const UpdateConnectionRequest$json = {
  '1': 'UpdateConnectionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'host', '3': 3, '4': 1, '5': 9, '10': 'host'},
    {'1': 'port', '3': 4, '4': 1, '5': 5, '10': 'port'},
    {'1': 'username', '3': 5, '4': 1, '5': 9, '10': 'username'},
    {'1': 'ssh_key_id', '3': 6, '4': 1, '5': 9, '10': 'sshKeyId'},
    {'1': 'startup_command', '3': 7, '4': 1, '5': 9, '10': 'startupCommand'},
  ],
};

/// Descriptor for `UpdateConnectionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateConnectionRequestDescriptor = $convert.base64Decode(
    'ChdVcGRhdGVDb25uZWN0aW9uUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCV'
    'IEbmFtZRISCgRob3N0GAMgASgJUgRob3N0EhIKBHBvcnQYBCABKAVSBHBvcnQSGgoIdXNlcm5h'
    'bWUYBSABKAlSCHVzZXJuYW1lEhwKCnNzaF9rZXlfaWQYBiABKAlSCHNzaEtleUlkEicKD3N0YX'
    'J0dXBfY29tbWFuZBgHIAEoCVIOc3RhcnR1cENvbW1hbmQ=');

@$core.Deprecated('Use deleteConnectionRequestDescriptor instead')
const DeleteConnectionRequest$json = {
  '1': 'DeleteConnectionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteConnectionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteConnectionRequestDescriptor = $convert
    .base64Decode('ChdEZWxldGVDb25uZWN0aW9uUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use sessionDescriptor instead')
const Session$json = {
  '1': 'Session',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'connection_id', '3': 2, '4': 1, '5': 9, '10': 'connectionId'},
    {'1': 'connection_name', '3': 3, '4': 1, '5': 9, '10': 'connectionName'},
    {'1': 'status', '3': 4, '4': 1, '5': 9, '10': 'status'},
    {'1': 'created_at', '3': 5, '4': 1, '5': 9, '10': 'createdAt'},
    {'1': 'last_activity', '3': 6, '4': 1, '5': 9, '10': 'lastActivity'},
  ],
};

/// Descriptor for `Session`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionDescriptor = $convert.base64Decode(
    'CgdTZXNzaW9uEg4KAmlkGAEgASgJUgJpZBIjCg1jb25uZWN0aW9uX2lkGAIgASgJUgxjb25uZW'
    'N0aW9uSWQSJwoPY29ubmVjdGlvbl9uYW1lGAMgASgJUg5jb25uZWN0aW9uTmFtZRIWCgZzdGF0'
    'dXMYBCABKAlSBnN0YXR1cxIdCgpjcmVhdGVkX2F0GAUgASgJUgljcmVhdGVkQXQSIwoNbGFzdF'
    '9hY3Rpdml0eRgGIAEoCVIMbGFzdEFjdGl2aXR5');

@$core.Deprecated('Use sessionListResponseDescriptor instead')
const SessionListResponse$json = {
  '1': 'SessionListResponse',
  '2': [
    {
      '1': 'sessions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.hive.Session',
      '10': 'sessions'
    },
  ],
};

/// Descriptor for `SessionListResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionListResponseDescriptor = $convert.base64Decode(
    'ChNTZXNzaW9uTGlzdFJlc3BvbnNlEikKCHNlc3Npb25zGAEgAygLMg0uaGl2ZS5TZXNzaW9uUg'
    'hzZXNzaW9ucw==');

@$core.Deprecated('Use createSessionRequestDescriptor instead')
const CreateSessionRequest$json = {
  '1': 'CreateSessionRequest',
  '2': [
    {'1': 'connection_id', '3': 1, '4': 1, '5': 9, '10': 'connectionId'},
    {'1': 'password', '3': 2, '4': 1, '5': 9, '10': 'password'},
  ],
};

/// Descriptor for `CreateSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createSessionRequestDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVTZXNzaW9uUmVxdWVzdBIjCg1jb25uZWN0aW9uX2lkGAEgASgJUgxjb25uZWN0aW'
    '9uSWQSGgoIcGFzc3dvcmQYAiABKAlSCHBhc3N3b3Jk');

@$core.Deprecated('Use closeSessionRequestDescriptor instead')
const CloseSessionRequest$json = {
  '1': 'CloseSessionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `CloseSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List closeSessionRequestDescriptor = $convert
    .base64Decode('ChNDbG9zZVNlc3Npb25SZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use terminalInputDescriptor instead')
const TerminalInput$json = {
  '1': 'TerminalInput',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '9': 0, '10': 'data'},
    {
      '1': 'resize',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.hive.Resize',
      '9': 0,
      '10': 'resize'
    },
    {
      '1': 'file',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.hive.FileUpload',
      '9': 0,
      '10': 'file'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `TerminalInput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List terminalInputDescriptor = $convert.base64Decode(
    'Cg1UZXJtaW5hbElucHV0Eh0KCnNlc3Npb25faWQYASABKAlSCXNlc3Npb25JZBIUCgRkYXRhGA'
    'IgASgMSABSBGRhdGESJgoGcmVzaXplGAMgASgLMgwuaGl2ZS5SZXNpemVIAFIGcmVzaXplEiYK'
    'BGZpbGUYBCABKAsyEC5oaXZlLkZpbGVVcGxvYWRIAFIEZmlsZUIJCgdwYXlsb2Fk');

@$core.Deprecated('Use resizeDescriptor instead')
const Resize$json = {
  '1': 'Resize',
  '2': [
    {'1': 'cols', '3': 1, '4': 1, '5': 13, '10': 'cols'},
    {'1': 'rows', '3': 2, '4': 1, '5': 13, '10': 'rows'},
  ],
};

/// Descriptor for `Resize`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resizeDescriptor = $convert.base64Decode(
    'CgZSZXNpemUSEgoEY29scxgBIAEoDVIEY29scxISCgRyb3dzGAIgASgNUgRyb3dz');

@$core.Deprecated('Use fileUploadDescriptor instead')
const FileUpload$json = {
  '1': 'FileUpload',
  '2': [
    {'1': 'filename', '3': 1, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `FileUpload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileUploadDescriptor = $convert.base64Decode(
    'CgpGaWxlVXBsb2FkEhoKCGZpbGVuYW1lGAEgASgJUghmaWxlbmFtZRISCgRkYXRhGAIgASgMUg'
    'RkYXRh');

@$core.Deprecated('Use terminalOutputDescriptor instead')
const TerminalOutput$json = {
  '1': 'TerminalOutput',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '9': 0, '10': 'data'},
    {'1': 'scrollback', '3': 2, '4': 1, '5': 12, '9': 0, '10': 'scrollback'},
    {
      '1': 'file',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.hive.FileUploaded',
      '9': 0,
      '10': 'file'
    },
    {
      '1': 'closed',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.hive.SessionClosed',
      '9': 0,
      '10': 'closed'
    },
    {
      '1': 'error',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.hive.Error',
      '9': 0,
      '10': 'error'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `TerminalOutput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List terminalOutputDescriptor = $convert.base64Decode(
    'Cg5UZXJtaW5hbE91dHB1dBIUCgRkYXRhGAEgASgMSABSBGRhdGESIAoKc2Nyb2xsYmFjaxgCIA'
    'EoDEgAUgpzY3JvbGxiYWNrEigKBGZpbGUYAyABKAsyEi5oaXZlLkZpbGVVcGxvYWRlZEgAUgRm'
    'aWxlEi0KBmNsb3NlZBgEIAEoCzITLmhpdmUuU2Vzc2lvbkNsb3NlZEgAUgZjbG9zZWQSIwoFZX'
    'Jyb3IYBSABKAsyCy5oaXZlLkVycm9ySABSBWVycm9yQgkKB3BheWxvYWQ=');

@$core.Deprecated('Use fileUploadedDescriptor instead')
const FileUploaded$json = {
  '1': 'FileUploaded',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'filename', '3': 2, '4': 1, '5': 9, '10': 'filename'},
  ],
};

/// Descriptor for `FileUploaded`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileUploadedDescriptor = $convert.base64Decode(
    'CgxGaWxlVXBsb2FkZWQSEgoEcGF0aBgBIAEoCVIEcGF0aBIaCghmaWxlbmFtZRgCIAEoCVIIZm'
    'lsZW5hbWU=');

@$core.Deprecated('Use sessionClosedDescriptor instead')
const SessionClosed$json = {
  '1': 'SessionClosed',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `SessionClosed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionClosedDescriptor = $convert.base64Decode(
    'Cg1TZXNzaW9uQ2xvc2VkEh0KCnNlc3Npb25faWQYASABKAlSCXNlc3Npb25JZBIWCgZyZWFzb2'
    '4YAiABKAlSBnJlYXNvbg==');

@$core.Deprecated('Use errorDescriptor instead')
const Error$json = {
  '1': 'Error',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `Error`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List errorDescriptor = $convert.base64Decode(
    'CgVFcnJvchISCgRjb2RlGAEgASgJUgRjb2RlEhgKB21lc3NhZ2UYAiABKAlSB21lc3NhZ2U=');
