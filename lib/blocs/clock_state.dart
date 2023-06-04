part of 'clock_cubit.dart';

@immutable
abstract class ClockState {}

class ClockUnset extends ClockState {}

class ClockRunning extends ClockState {
  DateTime started;
  DateTime target;
  Action action;

  ClockRunning(this.started, this.target, this.action);
}