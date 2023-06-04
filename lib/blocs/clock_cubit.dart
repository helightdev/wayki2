import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:wayki2/action.dart';

part 'clock_state.dart';

class ClockCubit extends Cubit<ClockState> {
  ClockCubit() : super(ClockUnset());

  void reset() {
    emit(ClockUnset());
  }

  void start(DateTime started, DateTime target, Action action) {
    emit(ClockRunning(started, target, action));
  }
}
