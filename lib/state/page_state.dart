import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/startup_view_store.dart';
import 'app_state.dart';

enum CueView { inbox, today, upcoming, list, board, calendar, quadrants }

enum CueListFilter { today, upcoming, completed }

class CueHomeUiState {
  const CueHomeUiState(this.view, this.filter);
  final CueView view;
  final CueListFilter filter;
}

final initialStartupViewProvider = Provider<StartupView>(
  (ref) => StartupView.today,
  dependencies: const [],
);

final cueHomeUiProvider = NotifierProvider<CueHomeUi, CueHomeUiState>(
  CueHomeUi.new,
  dependencies: [initialStartupViewProvider],
);

class CueHomeUi extends Notifier<CueHomeUiState> {
  @override
  CueHomeUiState build() {
    final view = _mapStartupView(ref.read(initialStartupViewProvider));
    final filter = view == CueView.upcoming
        ? CueListFilter.upcoming
        : CueListFilter.today;
    return CueHomeUiState(view, filter);
  }

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
    selectView(CueView.today);
  }
}

CueView _mapStartupView(StartupView view) {
  return switch (view) {
    StartupView.inbox => CueView.inbox,
    StartupView.today => CueView.today,
    StartupView.upcoming => CueView.upcoming,
    StartupView.list => CueView.list,
    StartupView.calendar => CueView.calendar,
    StartupView.quadrants => CueView.quadrants,
  };
}

MobileDestination? _mapViewToDestination(CueView view) {
  return switch (view) {
    CueView.inbox => MobileDestination.board,
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
  const MobileUiState(this.destination, this.showLater);
  final MobileDestination destination;
  final bool showLater;
}

final mobileUiProvider = NotifierProvider<MobileUi, MobileUiState>(
  MobileUi.new,
  dependencies: [initialStartupViewProvider],
);

class MobileUi extends Notifier<MobileUiState> {
  @override
  MobileUiState build() {
    final view = _mapStartupView(ref.read(initialStartupViewProvider));
    return MobileUiState(_mapViewToDestination(view)!, false);
  }

  void selectDestination(MobileDestination destination) {
    state = MobileUiState(destination, state.showLater);
  }

  void showLater(bool value) {
    state = MobileUiState(state.destination, value);
  }
}

void navigateToCueView(WidgetRef ref, CueView view) {
  ref.read(cueHomeUiProvider.notifier).selectView(view);
  final destination = _mapViewToDestination(view);
  if (destination != null) {
    ref.read(mobileUiProvider.notifier).selectDestination(destination);
  }
}

void navigateToMobileDestination(WidgetRef ref, MobileDestination destination) {
  ref.read(mobileUiProvider.notifier).selectDestination(destination);
  final view = _mapDestinationToView(destination);
  if (view != null) {
    ref.read(cueHomeUiProvider.notifier).selectView(view);
  }
}

CueView? _mapDestinationToView(MobileDestination destination) {
  return switch (destination) {
    MobileDestination.today => CueView.today,
    MobileDestination.board => CueView.inbox,
    MobileDestination.calendar => CueView.calendar,
    MobileDestination.quadrants => CueView.quadrants,
    MobileDestination.settings => null,
  };
}

enum BoardGroup { group, priority, dueDate }

final boardGroupProvider =
    NotifierProvider.autoDispose<BoardGroupSelection, BoardGroup>(
      BoardGroupSelection.new,
    );

class BoardGroupSelection extends Notifier<BoardGroup> {
  @override
  BoardGroup build() => BoardGroup.group;
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

class SetupAdminUiState {
  const SetupAdminUiState({
    this.submitting = false,
    this.obscurePassword = true,
    this.obscureConfirmPassword = true,
    this.error,
    this.interacted = false,
  });
  final bool submitting;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final String? error;
  final bool interacted;
}

final setupAdminUiProvider =
    NotifierProvider.autoDispose<SetupAdminUi, SetupAdminUiState>(
      SetupAdminUi.new,
    );

class SetupAdminUi extends Notifier<SetupAdminUiState> {
  @override
  SetupAdminUiState build() => const SetupAdminUiState();

  void setError(String? error) => state = SetupAdminUiState(
    submitting: state.submitting,
    obscurePassword: state.obscurePassword,
    obscureConfirmPassword: state.obscureConfirmPassword,
    error: error,
    interacted: true,
  );

  void setSubmitting(bool submitting) => state = SetupAdminUiState(
    submitting: submitting,
    obscurePassword: state.obscurePassword,
    obscureConfirmPassword: state.obscureConfirmPassword,
    error: submitting ? null : state.error,
    interacted: true,
  );

  void togglePasswordVisibility() => state = SetupAdminUiState(
    submitting: state.submitting,
    obscurePassword: !state.obscurePassword,
    obscureConfirmPassword: state.obscureConfirmPassword,
    error: state.error,
    interacted: state.interacted,
  );

  void toggleConfirmPasswordVisibility() => state = SetupAdminUiState(
    submitting: state.submitting,
    obscurePassword: state.obscurePassword,
    obscureConfirmPassword: !state.obscureConfirmPassword,
    error: state.error,
    interacted: state.interacted,
  );
}

