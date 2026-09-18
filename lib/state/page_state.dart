import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cue_task.dart';

enum CueView { inbox, today, upcoming, list, board, calendar, quadrants }

enum CueListFilter { today, upcoming, completed }

class CueHomeUiState {
  const CueHomeUiState(this.view, this.filter);
  final CueView view;
  final CueListFilter filter;
}

final cueHomeUiProvider =
    NotifierProvider.autoDispose<CueHomeUi, CueHomeUiState>(CueHomeUi.new);

class CueHomeUi extends Notifier<CueHomeUiState> {
  @override
  CueHomeUiState build() =>
      const CueHomeUiState(CueView.today, CueListFilter.today);

  void selectView(CueView view) {
    final filter = switch (view) {
      CueView.today => CueListFilter.today,
      CueView.upcoming => CueListFilter.upcoming,
      _ => state.filter,
    };
    state = CueHomeUiState(view, filter);
  }

  void selectFilter(CueListFilter filter) {
    state = CueHomeUiState(state.view, filter);
  }

  void focusToday() {
    state = const CueHomeUiState(CueView.today, CueListFilter.today);
  }
}

enum MobileDestination { today, board, calendar, quadrants, settings }

class MobileUiState {
  const MobileUiState(this.destination, this.showLater, this.boardStatus);
  final MobileDestination destination;
  final bool showLater;
  final CueTaskStatus boardStatus;
}

final mobileUiProvider = NotifierProvider.autoDispose<MobileUi, MobileUiState>(
  MobileUi.new,
);

class MobileUi extends Notifier<MobileUiState> {
  @override
  MobileUiState build() =>
      const MobileUiState(MobileDestination.today, false, CueTaskStatus.doing);

  void selectDestination(MobileDestination destination) {
    state = MobileUiState(destination, state.showLater, state.boardStatus);
  }

  void showLater(bool value) {
    state = MobileUiState(state.destination, value, state.boardStatus);
  }

  void selectBoardStatus(CueTaskStatus status) {
    state = MobileUiState(state.destination, state.showLater, status);
  }
}

enum BoardGroup { status, priority, dueDate }

final boardGroupProvider =
    NotifierProvider.autoDispose<BoardGroupSelection, BoardGroup>(
      BoardGroupSelection.new,
    );

class BoardGroupSelection extends Notifier<BoardGroup> {
  @override
  BoardGroup build() => BoardGroup.status;
  void select(BoardGroup group) => state = group;
}

final calendarDueOnlyProvider =
    NotifierProvider.autoDispose<CalendarDueOnly, bool>(CalendarDueOnly.new);

class CalendarDueOnly extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

enum QuadrantFilter { all, important, dueSoon }

final quadrantFilterProvider =
    NotifierProvider.autoDispose<QuadrantFilterSelection, QuadrantFilter>(
      QuadrantFilterSelection.new,
    );

class QuadrantFilterSelection extends Notifier<QuadrantFilter> {
  @override
  QuadrantFilter build() => QuadrantFilter.all;
  void select(QuadrantFilter filter) => state = filter;
}

class LoginUiState {
  const LoginUiState({
    this.submitting = false,
    this.obscurePassword = true,
    this.error,
    this.interacted = false,
  });
  final bool submitting;
  final bool obscurePassword;
  final String? error;
  final bool interacted;
}

final loginUiProvider = NotifierProvider.autoDispose<LoginUi, LoginUiState>(
  LoginUi.new,
);

class LoginUi extends Notifier<LoginUiState> {
  @override
  LoginUiState build() => const LoginUiState();

  void setError(String? error) => state = LoginUiState(
    submitting: state.submitting,
    obscurePassword: state.obscurePassword,
    error: error,
    interacted: true,
  );

  void setSubmitting(bool submitting) => state = LoginUiState(
    submitting: submitting,
    obscurePassword: state.obscurePassword,
    error: submitting ? null : state.error,
    interacted: true,
  );

  void togglePasswordVisibility() => state = LoginUiState(
    submitting: state.submitting,
    obscurePassword: !state.obscurePassword,
    error: state.error,
    interacted: state.interacted,
  );
}

class ServerConnectionUiState {
  const ServerConnectionUiState({this.connecting = false, this.error});
  final bool connecting;
  final String? error;
}

final serverConnectionUiProvider =
    NotifierProvider.autoDispose<ServerConnectionUi, ServerConnectionUiState>(
      ServerConnectionUi.new,
    );

class ServerConnectionUi extends Notifier<ServerConnectionUiState> {
  @override
  ServerConnectionUiState build() => const ServerConnectionUiState();
  void setConnecting(bool connecting) => state = ServerConnectionUiState(
    connecting: connecting,
    error: connecting ? null : state.error,
  );
  void setError(String? error) => state = ServerConnectionUiState(
    connecting: state.connecting,
    error: error,
  );
}
