import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:permission_handler/permission_handler.dart';// TODO: remove after test

import 'generated/l10n.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String _serverName = '';
  String _username = '';
  String _password = '';
  bool _obscurePassword = true;
  bool _passwordValid = true;

  Widget _buildButtons() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RaisedButton(
              child: Text(S.of(context).login),
              onPressed: _loginPressed,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RaisedButton(
              child: Text(S.of(context).register),
              onPressed: _registerPressed,
            ),
          ),
        )
      ],
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    );
  }

  Widget _buildInputs() {
    return Column(
      children: <Widget>[
        TextField(
          controller: _serverController,
          decoration: InputDecoration(labelText: S.of(context).server),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: RaisedButton(
            child: Text(S.of(context).testConnection),
            onPressed: _testConnectionPressed,
          ),
        ),
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(labelText: S.of(context).username),
        ),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
              labelText: S.of(context).password,
              errorText: _passwordValid ? null : S.of(context).passwordInvalid,
              suffixIcon: GestureDetector(
                onTap: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                child: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off),
              )),
        ),
      ],
    );
  }

  String _getLoginErrorMessage({String errCode}) {
    String message = 'ERROR';
    if (errCode == 'ERR_AUTH_NO_USERNAME') {
      message = S.of(context).noUsernameProvided;
    } else if (errCode == 'ERR_AUTH_NO_PASSWORD') {
      message = S.of(context).noPasswordProvided;
    } else if (errCode == 'ERR_AUTH_USER_NOT_EXIST') {
      message = S.of(context).userDontExist;
    } else if (errCode == 'ERR_AUTH_WRONG_PASSWORD') {
      message = S.of(context).wrongPassword;
    } else if (errCode == 'ERR_AUTH_USER_EXISTS') {
      message = S.of(context).userAlreadyExists;
    } else {
      throw ArgumentError('Error key not recognized.');
    }
    return message;
  }

  Future<void> _loginPressed() async {
    // Directory tmp = Directory('/storage/emulated/1/DCIM/Camera');
    Directory tmp = Directory('/storage/emulated/0/DCIM/Camera');
    if (await Permission.storage.request().isGranted) {
      print(tmp.existsSync());
      for (var item in tmp.listSync()) {
        print(item.path);
      }
    }

//    print((await getExternalStorageDirectories(type: StorageDirectory.dcim))[0]
//        .path); // TODO: remove

    bool connectionOk = await _testConnection(showAlerts: true);
    if (connectionOk) {
      if (_username.isEmpty || _password.isEmpty) {
        _showDialogWrapper(
            title: S.of(context).login, content: S.of(context).loginInfoEmpty);
      } else {
        try {
          String body =
              json.encode({'username': _username, 'password': _password});

          var loginResponse = await http.post(_serverName + 'api/auth/login',
              body: body,
              headers: {
                HttpHeaders.contentTypeHeader: 'application/json'
              }).timeout(Duration(seconds: 3));

          if (loginResponse == null || loginResponse.statusCode != 200) {
            if (loginResponse.statusCode == 401 && loginResponse.body != null) {
              // expected to receive with some JSON
              try {
                var respJson = json.decode(loginResponse.body);
                if (!respJson['success'] && respJson['err_code'] != null) {
                  _showAuthErrorDialog(
                      errCode: respJson['err_code'],
                      title: S.of(context).login);
                  return;
                }
              } on FormatException {} // do nothing, unknown error
              on ArgumentError {}
            }
            _showDialogWrapper(
                title: S.of(context).login,
                content: S.of(context).unknownLoginError);
          } else {
            var respJson = json.decode(loginResponse.body);
            var sp = await SharedPreferences.getInstance();
            sp.setString("accessToken", respJson['token']);
            sp.setString("username", _username);

            // TODO: redirect to the main screen
          }
        } on TimeoutException {
          _showDialogWrapper(
              title: S.of(context).login,
              content: S.of(context).timeoutExceeded(_serverName));
        } on SocketException {
          _showDialogWrapper(
              title: S.of(context).login,
              content: S.of(context).serverConnectionFailed(_serverName));
        }
      }
    }
  }

  Future<void> _registerPressed() async {
    bool connectionOk = await _testConnection(showAlerts: true);
    if (connectionOk) {}
    if (_username.isEmpty || _password.isEmpty) {
      _showDialogWrapper(
          title: S.of(context).register, content: S.of(context).loginInfoEmpty);
    } else {
      bool newPassValid = _validatePassword(_password);
      if (_passwordValid != newPassValid) {
        setState(() {
          _passwordValid = newPassValid;
        });
        if (!_passwordValid) return;
      }

      try {
        String body =
            json.encode({'username': _username, 'password': _password});

        var regResponse = await http.post(_serverName + 'api/auth/users',
            body: body,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json'
            }).timeout(Duration(seconds: 3));

        if (regResponse == null || regResponse.statusCode != 201) {
          if (regResponse.statusCode == 401 && regResponse.body != null) {
            // expected to receive with some JSON
            try {
              var respJson = json.decode(regResponse.body);
              if (!respJson['success'] && respJson['err_code'] != null) {
                _showAuthErrorDialog(
                    errCode: respJson['err_code'],
                    title: S.of(context).register);
                return;
              }
            } on FormatException {} // do nothing, unknown error
            on ArgumentError {}
          }
          _showDialogWrapper(
              title: S.of(context).register,
              content: S.of(context).unknownRegisterError);
        } else {
          var respJson = json.decode(regResponse.body);
          assert(respJson['success']);
          _showDialogWrapper(
              title: S.of(context).register,
              content: S.of(context).registeredSuccessfully(_username));
        }
      } on TimeoutException {
        _showDialogWrapper(
            title: S.of(context).register,
            content: S.of(context).timeoutExceeded(_serverName));
      } on SocketException {
        _showDialogWrapper(
            title: S.of(context).register,
            content: S.of(context).serverConnectionFailed(_serverName));
      }
    }
  }

  void _showDialogWrapper({String title, String content}) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: <Widget>[
                FlatButton(
                  child: Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ));
  }

  void _showAuthErrorDialog({String errCode, String title}) {
    String message = _getLoginErrorMessage(errCode: errCode);
    _showDialogWrapper(title: title, content: message);
  }

  Future<void> _testConnectionPressed() async {
    await _testConnection(showAlerts: true, showSuccess: true);
  }

  Future<bool> _testConnection(
      {bool showAlerts = false, bool showSuccess = false}) async {
    if (_serverName.isEmpty) {
      if (showAlerts) {
        _showDialogWrapper(
            title: S.of(context).connectionStatus,
            content: S.of(context).serverEmpty);
      }
      return false;
    } else if (!(_serverName.startsWith('http://') ||
            _serverName.startsWith('https://')) ||
        !_serverName.endsWith('/')) {
      if (showAlerts) {
        _showDialogWrapper(
            title: S.of(context).connectionStatus,
            content: S.of(context).serverFormatWrong);
      }
      return false;
    } else {
      try {
        var response =
            await http.get(_serverName + 'ping').timeout(Duration(seconds: 3));
        if (response == null || response.statusCode != 200) {
          _showDialogWrapper(
              title: S.of(context).connectionStatus,
              content: S.of(context).serverConnectionFailed(_serverName));
        } else {
          assert(response.body == 'Pong!');
          // Connection OK!
          if (showSuccess) {
            _showDialogWrapper(
                title: S.of(context).connectionStatus,
                content: S.of(context).serverConnectionSuccessful(_serverName));
          }
          return true;
        }
      } on TimeoutException {
        if (showAlerts) {
          _showDialogWrapper(
              title: S.of(context).connectionStatus,
              content: S.of(context).timeoutExceeded(_serverName));
        }
      } on SocketException {
        if (showAlerts) {
          _showDialogWrapper(
              title: S.of(context).connectionStatus,
              content: S.of(context).serverConnectionFailed(_serverName));
        }
      } on HandshakeException {
        if (showAlerts) {
          _showDialogWrapper(
              title: S.of(context).connectionStatus,
              content: S.of(context).serverConnectionFailed(_serverName));
        }
      }
      return false;
    }
  }

  bool _validatePassword(String password) {
    if (password == null || password.length < 8) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).login),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[_buildInputs(), _buildButtons()],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _serverController.addListener(() {
      _serverName = _serverController.text;
    });

    _usernameController.addListener(() {
      _username = _usernameController.text;
    });

    _passwordController.addListener(() {
      _password = _passwordController.text;
    });
    super.initState();
  }
}
