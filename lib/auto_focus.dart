import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:math';

enum KeyEvent { Up, Down, Left, Right, Enter }

class AutoFocusContainer extends StatefulWidget {
  final Widget child;

  const AutoFocusContainer({Key key, this.child}) : super(key: key);

  @override
  _AutoFocusContainerState createState() => _AutoFocusContainerState();
}

class _AutoFocusContainerState extends State<AutoFocusContainer> {
  final focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    FocusScope.of(context).requestFocus(focusNode);

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _afterLayout());
    }

    return RawKeyboardListener(
        focusNode: focusNode, onKey: _handleKey, child: widget.child);
  }

  Function _createAufoFocusFilterVisitor(List<StatefulElement> afElementList) {
    visitor(element) {
      if (element.widget is AutoFocus) {
        StatefulElement stfElement = element;
        // bad
//        AutoFocus afWidget = stfElement.widget;
//        _AutoFocusState afState = stfElement.state;
//        afState.calculateRenderRect();
        afElementList.add(element);
      }
      element.visitChildren(visitor);
    }

    return visitor;
  }

  _handleKey(event) {
    if (event is RawKeyDownEvent && event.data is RawKeyEventDataAndroid) {
      RawKeyDownEvent rawKeyDownEvent = event;
      RawKeyEventDataAndroid rawKeyEventDataAndroid = rawKeyDownEvent.data;
      print("keyCode: ${rawKeyEventDataAndroid.keyCode}");

      List<StatefulElement> afElementList = [];
      this
          .context
          .visitChildElements(_createAufoFocusFilterVisitor(afElementList));
      print(afElementList);
      // 找到当前选中的那个节点
      StatefulElement currentFocusedElement;
      afElementList.forEach((stfElement) {
        _AutoFocusState afState = stfElement.state;
        if (afState.focused) {
          currentFocusedElement = stfElement;
        }
      });
//      assert(currentFocusedElement != null);
      // 如果当前没有节点没有被选中，则选中最左上角的节点
      if (currentFocusedElement == null) {
        _setFirstFocusNode();
        return;
      }

      _calculateAllAutoFocusNode(afElementList);
      switch (rawKeyEventDataAndroid.keyCode) {
        case 19: //KEY_UP
          _jumpToNextAutoFocus(
              currentFocusedElement, afElementList, KeyEvent.Up);
          break;
        case 20: //KEY_DOWN
          _jumpToNextAutoFocus(
              currentFocusedElement, afElementList, KeyEvent.Down);
          break;
        case 21: //KEY_LEFT
          _jumpToNextAutoFocus(
              currentFocusedElement, afElementList, KeyEvent.Left);
          break;
        case 22: //KEY_RIGHT
          _jumpToNextAutoFocus(
              currentFocusedElement, afElementList, KeyEvent.Right);
          break;
        case 23:
        case 66: //KEY_CENTER
          AutoFocus afWidget = currentFocusedElement.widget;
          print('Enter');
          afWidget.onEnter();
          break;
        default:
          break;
      }
    }
  }

  void _calculateAllAutoFocusNode(List<StatefulElement> afElementList) {
    afElementList.forEach((stfElement) {
      if (stfElement.widget is AutoFocus) {
        _AutoFocusState afState = stfElement.state;
        afState.calculateRenderRect();
      }
    });
  }

  void _setFirstFocusNode() {
    print('setFirstFocusNode');
    List<StatefulElement> afElementList = [];
    this
        .context
        .visitChildElements(_createAufoFocusFilterVisitor(afElementList));
    print(afElementList);
    _calculateAllAutoFocusNode(afElementList);

    bool noneOfNodeFocused = true;
    double minDistanceSquared = double.infinity;
    _AutoFocusState topLeftElementState;
    afElementList.forEach((stfElement) {
      _AutoFocusState afState = stfElement.state;
      if (afState.focused) {
        noneOfNodeFocused = false;
      }
      // 找到距离坐标原点最近一的一个节点
      if (afState.rect.topLeft.distanceSquared < minDistanceSquared) {
        minDistanceSquared = afState.rect.topLeft.distanceSquared;
        topLeftElementState = afState;
      }
    });
    if (noneOfNodeFocused && topLeftElementState != null) {
      topLeftElementState.setFocused(true);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _afterLayout() async {
    return await Future.delayed(const Duration(milliseconds: 700), () {
      _setFirstFocusNode();
    });
  }

  void _jumpToNextAutoFocus(StatefulElement currentFocusElement,
      List<StatefulElement> afElementList, KeyEvent event) {
    _AutoFocusState currentElementState = currentFocusElement.state;

    // 先根据方向筛选出一个候选人列表
    List<StatefulElement> candidateList = afElementList.where((stfElement) {
      _AutoFocusState afState = stfElement.state;
      Rect targetFocusRect = afState.rect;
      Rect currentFocusRect = currentElementState.rect;
      switch (event) {
        case KeyEvent.Up:
          return targetFocusRect.bottomCenter.dy <
              currentFocusRect.topCenter.dy;
        case KeyEvent.Down:
          return targetFocusRect.topCenter.dy >
              currentFocusRect.bottomCenter.dy;
        case KeyEvent.Left:
          return targetFocusRect.centerRight.dx <
              currentFocusRect.centerLeft.dx;
        case KeyEvent.Right:
          return targetFocusRect.centerLeft.dx >
              currentFocusRect.centerRight.dx;
        default:
          break;
      }
    }).toList();
    print(candidateList);

    // 在候选人列表中找到距离最近的那一个
    double distanceSquaredBetweenTwoRect(
        Rect sourceRect, Rect targetRect, KeyEvent event) {
      Offset sourceOffset;
      Offset targetOffset;
      switch (event) {
        case KeyEvent.Up:
          sourceOffset = sourceRect.topCenter;
          targetOffset = targetRect.bottomCenter;
          break;
        case KeyEvent.Down:
          sourceOffset = sourceRect.bottomCenter;
          targetOffset = targetRect.topCenter;
          break;
        case KeyEvent.Left:
          sourceOffset = sourceRect.centerLeft;
          targetOffset = targetRect.centerRight;
          break;
        case KeyEvent.Right:
          sourceOffset = sourceRect.centerRight;
          targetOffset = targetRect.centerLeft;
          break;
        default:
          return double.infinity;
      }
      return (sourceOffset.dx - targetOffset.dx).abs() *
              (sourceOffset.dx - targetOffset.dx).abs() +
          (sourceOffset.dy - targetOffset.dy).abs() *
              (sourceOffset.dy - targetOffset.dy).abs();
    }

    _AutoFocusState nextElementState;
    StatefulElement nextElement;
    double minDistanceSquared = double.infinity;

    candidateList.forEach((stfElement) {
      _AutoFocusState elementState = stfElement.state;
      Rect targetRect = elementState.rect;
      Rect currentRect = currentElementState.rect;

      var distanceSquared =
          distanceSquaredBetweenTwoRect(currentRect, targetRect, event);
      print('distanceSquared:${distanceSquared}');
      if (distanceSquared < minDistanceSquared) {
        minDistanceSquared = distanceSquared;
        nextElementState = elementState;
        nextElement = stfElement;
      }
    });

    if (nextElementState != null) {
      // 判断是否需要滚动到该区域
      _needScrollToElement(nextElement, event);

      nextElementState.setFocused(true);
      currentElementState.setFocused(false);
    }
  }

  _needScrollToElement(StatefulElement element, KeyEvent event) {
    ScrollController sc;
    _AutoFocusState state = element.state;
    visitor(ancessElement) {
      if (ancessElement.widget is ScrollView) {
        ScrollView sv = ancessElement.widget as ScrollView;
        sc = sv.controller;
      }
      if (sc != null) {
        final screenHeight = MediaQuery.of(context).size.height;
        final delta = 40;

        final rect = state.rect;
        print(rect.topCenter.dy);
        print(rect.bottomCenter.dy);
        if (rect.topCenter.dy < 0 || rect.bottomCenter.dy > screenHeight) {
          if (event == KeyEvent.Down) {
            sc.animateTo(
              rect.topCenter.dy + sc.offset - delta,
              curve: Curves.ease,
              duration: Duration(milliseconds: 300),
            );
          }
          if (event == KeyEvent.Up) {
            sc.animateTo(
              rect.bottomCenter.dy + sc.offset - screenHeight + delta,
              curve: Curves.ease,
              duration: Duration(milliseconds: 300),
            );
          }
          return false;
        }
      }
      return true;
    }

    element.visitAncestorElements(visitor);
  }
}

class AutoFocus extends StatefulWidget {
  final Widget child;
  final Function onEnter;

  const AutoFocus({Key key, this.child, this.onEnter}) : super(key: key);

  @override
  _AutoFocusState createState() => _AutoFocusState();
}

class _AutoFocusState extends State<AutoFocus> {
  var focused = false;

  Offset position = Offset(0, 0);
  Size size = Size(0, 0);

  Rect get rect {
    return position & size;
  }

  @override
  Widget build(BuildContext context) {
    print('autofocus build');
    BoxDecoration boxDecoration;
    if (focused) {
      boxDecoration = BoxDecoration(
          border: Border.all(width: 1.0, color: Theme.of(context).primaryColor),
          borderRadius:
              new BorderRadius.all(new Radius.circular(6)));
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _afterLayout());
    }
    final padding = -1.0;
    return Stack(
      overflow: Overflow.visible,
      children: <Widget>[
        Positioned(
          top: padding,
          left: padding,
          bottom: padding,
          right: padding,
          child: Container(
            foregroundDecoration: boxDecoration,
          ),
        ),
        Center(child: widget.child),
      ],
    );
  }

  calculateRenderRect() {
    // 首先获取到最原始的位置信息 基于全局的坐标系
    final RenderBox renderBox = context.findRenderObject();
    final size = renderBox.size;
    var position = renderBox.localToGlobal(Offset.zero);

    // 查找父容器中是否有存在可滚动的ScrollView
    RenderBox svRenderBox;
    ScrollController sc;
    visitor(ancestorElement) {
      if (ancestorElement.widget is ScrollView) {
        ScrollView sv = ancestorElement.widget as ScrollView;

        if (sv.controller != null) {
          svRenderBox = ancestorElement.findRenderObject();
          sc = sv.controller;
          return false;
        }
      }
      return true;
    }

    context.visitAncestorElements(visitor);

    // ScrollView自身的全局位置
    var svPosition = Offset(0, 0);
    // ScrollView自身当前的偏移
    double svOffset = 0;
    if (svRenderBox != null && sc != null) {
      svPosition = svRenderBox.localToGlobal(Offset.zero);
      svOffset = sc.offset;
//      position = Offset(position.dx, position.dy + svOffset);
    }
    print(position);
    this.position = position;
    this.size = size;
  }

  Future<void> _afterLayout() async {
    return await Future.delayed(const Duration(milliseconds: 600), () {
//      calculateRenderRect();
    });
  }

  @override
  void initState() {
    super.initState();
  }

  setFocused(focused) {
    this.setState(() {
      this.focused = focused;
    });
  }
}
