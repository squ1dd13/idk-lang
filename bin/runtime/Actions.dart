import 'Concepts.dart';

/// Something that happens.
abstract class Action {
  void execute();
}

class SetAction implements Action {
  Concept _target;
  Concept _value;

  @override
  void execute() {

  }

}