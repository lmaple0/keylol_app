import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keylol_api/keylol_api.dart';
import 'package:keylol_flutter/repository/authentication_repository.dart';

part 'authentication_event.dart';
part 'authentication_state.dart';

class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  final Keylol _client;
  final AuthenticationRepository _repository;
  late StreamSubscription<AuthenticationStatus> _streamSubscription;

  AuthenticationBloc(this._client, this._repository)
    : super(AuthenticationRestoring()) {
    _streamSubscription = _repository.status.listen(
      (status) => add(AuthenticationStatusChanged(status)),
    );
    on<AuthenticationStatusChanged>(_onAuthenticationStatusChanged);
    on<AuthenticationStatusFetched>(_onAuthenticationStatusFetched);
    add(AuthenticationStatusFetched());
  }

  @override
  Future<void> close() async {
    await _streamSubscription.cancel();
    return super.close();
  }

  Future<void> _onAuthenticationStatusChanged(
    AuthenticationStatusChanged event,
    Emitter<AuthenticationState> emit,
  ) async {
    switch (event.status) {
      case AuthenticationStatus.restoring:
        emit(AuthenticationRestoring());
        break;
      case AuthenticationStatus.unauthenticated:
        emit(AuthenticationUnauthenticated());
        break;
      case AuthenticationStatus.authenticated:
        emit(AuthenticationAuthenticated(_repository.profile));
        break;
    }
  }

  Future<void> _onAuthenticationStatusFetched(
    AuthenticationStatusFetched event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(AuthenticationRestoring());
    try {
      final cookies = await _client.cookies();
      if (!cookies.any(
        (cookie) => cookie.entries.any(
          (entry) => entry.key.endsWith('_auth') && entry.value.isNotEmpty,
        ),
      )) {
        emit(AuthenticationUnauthenticated());
        return;
      }
      final response = await _client
          .dio()
          .post<Map<String, dynamic>>(
            '/api/mobile/index.php',
            queryParameters: {'module': 'profile'},
          )
          .timeout(const Duration(seconds: 15));
      final profile = ApiResponse.empty(response.data!).variables;
      _repository.profile = profile;
      emit(
        profile.memberUid.isEmpty || profile.memberUid == '0'
            ? AuthenticationUnauthenticated()
            : AuthenticationAuthenticated(profile),
      );
    } catch (_) {
      // A network failure does not mean the saved session has expired.
      final profile = _repository.profile;
      emit(
        profile.memberUid.isNotEmpty && profile.memberUid != '0'
            ? AuthenticationAuthenticated(profile)
            : AuthenticationRestoreFailed(),
      );
    }
  }
}
