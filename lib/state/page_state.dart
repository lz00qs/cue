import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';
import '../models/cue_task.dart';

enum CueView { inbox, today, upcoming, list, board, calendar, quadrants }

enum CueListFilter { today, upcoming, completed }

class CueHomeUiState {
  const CueHomeUiState(this.view, this.filter);
  final CueView view;
  final CueListFilter filter;
}

final cueHomeUiProvider =
    NotifierProvider<CueHomeUi, CueHomeUiState>(CueHomeUi.new);

class CueHomeUi extends Notifier<CueHomeUiState> {
  @override
  CueHomeUiState build() =>
      const CueHomeUiState(CueView.today, CueListFilter.today);

  void selectView(CueView view, {bool syncMobile = true}) {
    final filter = switch (view) {
      CueView.today => CueListFilter.today,
      CueView.upcoming => CueListFilter.upcoming,
      _ => state.filter,
    };
    state = CueHomeUiState(view, filter);
    if (syncMobile) {
      final dest = _mapViewToDestination(view);
      if (dest != null) {
        ref
            .read(mobileUiProvider.notifier)
            .selectDestination(dest, syncDesktop: false);
      }
    }
  }

  void selectFilter(CueListFilter filter) {
    state = CueHomeUiState(state.view, filter);
  }

  void focusToday() {
    selectView(CueView.today);
  }
}

MobileDestination? _mapViewToDestination(CueView view) {
  return switch (view) {
    CueView.inbox => MobileDestination.today,
    CueView.today => MobileDestination.today,
    CueView.upcoming => MobileDestination.today,
    CueView.list => MobileDestination.today,
    CueView.board => MobileDestination.board,
    CueView.calendar => MobileDestination.calendar,
    CueView.quadrants => MobileDestination.quadrants,
  };
}

enum MobileDestination { today, board, calendar, quadrants, settings }

class MobileUiState {
  const MobileUiState(this.destination, this.showLater, this.boardStatus);
  final MobileDestination destination;
  final bool showLater;
  final CueTaskStatus boardStatus;
}

final mobileUiProvider = NotifierProvider<MobileUi, MobileUiState>(
  MobileUi.new,
);

class MobileUi extends Notifier<MobileUiState> {
  @override
  MobileUiState build() =>
      const MobileUiState(MobileDestination.today, false, CueTaskStatus.doing);

  void selectDestination(MobileDestination destination, {bool syncDesktop = true}) {
    state = MobileUiState(destination, state.showLater, state.boardStatus);
    if (syncDesktop) {
      final view = _mapDestinationToView(destination);
      if (view != null) {
        ref
            .read(cueHomeUiProvider.notifier)
            .selectView(view, syncMobile: false);
      }
    }
  }

  void showLater(bool value) {
    state = MobileUiState(state.destination, value, state.boardStatus);
  }

  void selectBoardStatus(CueTaskStatus status) {
    state = MobileUiState(state.destination, state.showLater, status);
  }
}

CueView? _mapDestinationToView(MobileDestination destination) {
  return switch (destination) {
    MobileDestination.today => CueView.today,
    MobileDestination.board => CueView.board,
    MobileDestination.calendar => CueView.calendar,
    MobileDestination.quadrants => CueView.quadrants,
    MobileDestination.settings => null,
  };
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

final calendarFocusedMonthProvider =
    NotifierProvider.autoDispose<CalendarFocusedMonth, DateTime>(
      CalendarFocusedMonth.new,
    );

class CalendarFocusedMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final store = ref.read(taskStoreProvider);
    final today = store?.today ?? DateTime.now();
    return DateTime(today.year, today.month);
  }

  void previousMonth() {
    state = DateTime(state.year, state.month - 1);
  }

  void nextMonth() {
    state = DateTime(state.year, state.month + 1);
  }

  void resetToToday() {
    final store = ref.read(taskStoreProvider);
    final today = store?.today ?? DateTime.now();
    state = DateTime(today.year, today.month);
  }

  void setMonth(DateTime month) {
    state = DateTime(month.year, month.month);
  }
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
