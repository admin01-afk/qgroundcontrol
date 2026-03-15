## AAD docs

## kamikaze folder

``` text
class KamikazeLocManager
// this class has QGeoCoordinate _coordinate
// which is read and set by coordinate Q_PROPERTY
qml exposed functions:
  Q_INVOKABLE void setCoordinate(QGeoCoordinate coord);
    _coordinate = coord;
    emit coordinateChanged();

  Q_INVOKABLE void sendParameters(QGeoCoordinate coord);
    send KAMIKAZE_LAT and KAMIKAZE_LON parameters to activeVehicle

  Q_INVOKABLE void clearCoordinate();
    Zeroes out _coordinate and sends Zeroed params

```

also check: qgroundcontrol/src/UI/AppSettings/Kamikaze.qml

## RosBridge folder

``` text
class RosBridgeNode
registered to QGroundControlQmlGlobal so accessable in qml's with QGroundControl.rosBridge
which calls the RosBridgeNode::instance() function calling constructor that creates a single instance
creating and spinning the node 'RosBridgeNode_qgc'
```

actual node belongs to RosImpl class, more info in [CMakeLists section](#cmakelists).

``` text
qml exposed functions:
  Q_INVOKABLE void callService(const QString& serviceName);
    and functions like void startYolo() { callService("/start_yolo"); }
    so all the srv names in one place, not across qml files
```

## server folder

``` text
class ServerManager
  communication with competition server
  using QNetworkRequest's

  Telem loop management
  server_sim: server_sim process management (qgroundcontrol/src/AAD/server_sim/server.py)

  signal: errorOccurred listened from MainWindow.qml that shows MessageDialog
```

## server_sim folder

``` text
copied from     savasan_2025/comm_pkg/server_sim
added gui.py for server with arg: '-gui' for toggle button
2 fake planes circling telem data to server
```

## CMakeLists {#cmakelists}

CMakeLists.txt

``` text
RosBridge has a private class 'RosImpl' that Ros libs linked to separetly.
  1) Hides ROS types from the header
    Your header is included by lots of Qt/QML-related code.
    If it directly contained all ROS internals, the compile surface would get messy fast.

  2) Avoids Qt MOC issues:
    Qt’s meta-object compiler is picky with headers containing templates and heavy third-party types.
    Keeping ROS internals out of the public header reduces trouble.

  3) Reduces rebuilds: If you change ROS internals in .cc, fewer unrelated files need recompiling.
```
