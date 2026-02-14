#include "ServerManager.h"

/* ============================================================================
 * Qt / STL Includes
 * ========================================================================== */
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QUrl>
#include <QDebug>
#include <QDir>
#include <QApplicationStatic>
#include "Vehicle/MultiVehicleManager.h"
#include "Vehicle/Vehicle.h"
#include "FactSystem/Fact.h"

#include <functional>

/* ============================================================================
 * Singleton Instance
 * ========================================================================== */

Q_APPLICATION_STATIC(ServerManager, _serverManager)

ServerManager* ServerManager::instance()
{
    return _serverManager();
}

/* ============================================================================
 * Constructor / Initialization
 * ========================================================================== */

ServerManager::ServerManager(QObject* parent)
    : QObject(parent)
{
    // Network manager
    _nam = new QNetworkAccessManager(this);

    // Telemetry loop
    _telemTimer = new QTimer(this);
    _telemTimer->setInterval(600);
    connect(_telemTimer, &QTimer::timeout,
            this, &ServerManager::_telemLoop);

    // Prevent stray server processes on app exit
    connect(qApp, &QCoreApplication::aboutToQuit,
            this, &ServerManager::stopServerSim);
}

/* ============================================================================
 * HTTP / JSON Helper Utilities
 * ========================================================================== */
static QString opToString(QNetworkAccessManager::Operation op)
{
    switch (op) {
    case QNetworkAccessManager::GetOperation:    return "GET";
    case QNetworkAccessManager::PostOperation:   return "POST";
    case QNetworkAccessManager::PutOperation:    return "PUT";
    case QNetworkAccessManager::DeleteOperation: return "DELETE";
    default:                                     return "UNKNOWN";
    }
}
void ServerManager::requestJson(
    QNetworkAccessManager::Operation op,
    const QString& path,
    const QJsonObject* body,
    std::function<void(const QJsonObject&)> onSuccess)
{
    QUrl url(_baseUrl + path);
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QNetworkReply* reply = nullptr;

    if (op == QNetworkAccessManager::GetOperation) {
        reply = _nam->get(req);
    }
    else if (op == QNetworkAccessManager::PostOperation) {
        QByteArray payload = body
            ? QJsonDocument(*body).toJson(QJsonDocument::Compact)
            : QByteArray{};
        reply = _nam->post(req, payload);
    }
    else {
        emit errorOccurred("error requesting json","Unsupported HTTP operation");
        return;
    }

    connect(reply, &QNetworkReply::finished, this,
        [this, reply, onSuccess, op, path]()
        {
            const int httpStatus =
                reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

            const QByteArray data = reply->readAll();

            // Network-level error
            if (reply->error() != QNetworkReply::NoError) {
                emit errorOccurred(
                    tr("Network Error"),
                    QString("%1 %2\nHTTP %3: %4\n%5")
                        .arg(opToString(op))          // GET / POST / ...
                        .arg(path)                    // endpoint path
                        .arg(httpStatus)              // HTTP code
                        .arg(reply->errorString())    // Qt error
                        .arg(QString::fromUtf8(data)) // server body (if any)
                );
                reply->deleteLater();
                return;
            }

            // JSON parsing
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(data, &err);

            if (err.error != QJsonParseError::NoError || !doc.isObject()) {
                emit errorOccurred( "error parsing json",
                    QString("Invalid JSON response (HTTP %1)").arg(httpStatus)
                );
                reply->deleteLater();
                return;
            }

            if (onSuccess)
                onSuccess(doc.object());

            reply->deleteLater();
        });
}

QJsonObject ServerManager::qvariantmapToJson(const QVariantMap& m) const
{
    QJsonObject obj;

    for (auto it = m.constBegin(); it != m.constEnd(); ++it) {
        const QVariant& v = it.value();

        switch (v.typeId()) {
        case QMetaType::Bool:
            obj.insert(it.key(), v.toBool());
            break;
        case QMetaType::Int:
        case QMetaType::LongLong:
            obj.insert(it.key(), QJsonValue::fromVariant(v.toLongLong()));
            break;
        case QMetaType::Double:
            obj.insert(it.key(), v.toDouble());
            break;
        default:
            obj.insert(it.key(), v.toString());
            break;
        }
    }

    return obj;
}

/* ============================================================================
 * Public API — Authentication / Queries
 * ========================================================================== */

void ServerManager::login(const QString& username, const QString& password)
{
    QJsonObject body{
        {"kadi", username},
        {"sifre", password}
    };

    requestJson(
        QNetworkAccessManager::PostOperation,
        "/api/giris",
        &body,
        [this](const QJsonObject& obj)
        {
            if (obj.contains("takim_numarasi"))
                emit loginSucceeded(obj["takim_numarasi"].toInt());
            else
                emit loginFailed(obj.value("error").toString("Login failed"));
        }
    );
}

void ServerManager::getQRCoordinates()
{
    requestJson(
        QNetworkAccessManager::GetOperation,
        "/api/qr_koordinati",
        nullptr,
        [this](const QJsonObject& obj)
        {
            if (!obj.contains("qrEnlem") || !obj.contains("qrBoylam")) {
                emit errorOccurred("error getting QR","Invalid QR coordinate payload");
                return;
            }

            emit qrCoordinatesReceived(QGeoCoordinate(
                obj["qrEnlem"].toDouble(),
                obj["qrBoylam"].toDouble()
            ));
        }
    );
}

void ServerManager::checkConnection(bool emitErr)
{
    QNetworkRequest req{ QUrl(_baseUrl) };
    req.setAttribute(QNetworkRequest::RedirectionTargetAttribute, true);

    QNetworkReply* reply = _nam->get(req);

    connect(reply, &QNetworkReply::finished, this, [this, reply, emitErr]() {
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray data = reply->readAll();

        // If we received an HTTP status (200, 404, 500, etc.) the server answered
        // at transport level and should be considered reachable.
        if (httpStatus != 0) {
            emit connectionResult(true);
        } else {
            // No HTTP status — this is a transport/network-level failure.
            if (reply->error() != QNetworkReply::NoError) {

                if(emitErr) emit errorOccurred(
                    tr("Network Error"),
                    QString("GET %1\n%2\n%3")
                        .arg(_baseUrl)
                        .arg(reply->errorString())
                        .arg(QString::fromUtf8(data))
                );
                emit connectionResult(false);
            } else {
                // Extremely unlikely: no httpStatus and no network error.
                // Treat as unreachable to be conservative.
                emit connectionResult(false);
            }
        }

        reply->deleteLater();
    });
}

/* ============================================================================
 * Server Simulator Process Management
 * ========================================================================== */

void ServerManager::startServerSim()
{
    if (_serversimProcess) {
        qWarning() << "Server sim already running";
        return;
    }

    _serversimProcess = new QProcess(this);
    _serversimProcess->setProcessChannelMode(QProcess::MergedChannels);

    connect(_serversimProcess,
            &QProcess::readyReadStandardOutput,
            this, [this]() {

        const QString text =
            QString::fromUtf8(_serversimProcess->readAllStandardOutput());

        for (const QString& line : text.split('\n', Qt::SkipEmptyParts))
            appendLog(line);
    });

    connect(_serversimProcess,
            QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int code, QProcess::ExitStatus status) {

        appendLog(
            QString("Server sim exited: %1 (%2)").arg(code).arg(status)
        );

        _serversimProcess->deleteLater();
        _serversimProcess = nullptr;
        emit serversimRunningChanged();
    });

    const QString script =
        QDir::homePath() + "/qgroundcontrol/src/AAD/server_sim/server.py";

    _serversimProcess->start("python3", { script,"-gui"});

    if (!_serversimProcess->waitForStarted(1500)) {
        appendLog(QString("Failed to start server sim: %1").arg(script));
        _serversimProcess->deleteLater();
        _serversimProcess = nullptr;
        emit serversimRunningChanged();
        return;
    }

    emit serversimRunningChanged();
}

void ServerManager::stopServerSim()
{
    if (_serversimProcess)
        _serversimProcess->terminate();
}

bool ServerManager::serversimRunning() const
{
    return _serversimProcess &&
           _serversimProcess->state() != QProcess::NotRunning;
}

/* ============================================================================
 * Telemetry Loop
 * ========================================================================== */

void ServerManager::_telemLoop()
{
    // Check loop Hz at least 1 and less than 2
    if (!_telemElapsedTimer.isValid()){
        _telemElapsedTimer.start();
    }else{
        qint64 dtMs = _telemElapsedTimer.restart();
        constexpr int EXPECTED_HZ = 1;      // server sim = 1 Hz
        constexpr int MAX_DT_MS  = 1000;    // 1Hz
        constexpr int MIN_DT_MS  = 500;     // 2Hz

        if (dtMs > MAX_DT_MS) { // < 1Hz
            appendLog(QString(
                "[WARN] Telemetry slow: %1 ms (%2 Hz expected)"
            ).arg(dtMs).arg(EXPECTED_HZ));
        }
        if (dtMs < MIN_DT_MS) { // > 2Hz
            appendLog(QString(
                "[WARN] Telemetry fast: %1 ms (%2 Hz expected)"
            ).arg(dtMs).arg(EXPECTED_HZ));
        }
    }

    MultiVehicleManager* manager = MultiVehicleManager::instance();
    if (!manager) {qDebug() << "[TELEM] no Vehicle"; return;}

    Vehicle* vehicle = manager->activeVehicle();
    if (!vehicle) {qDebug() << "[TELEM] no Vehicle"; return;}

    QJsonObject body;
    body["takim_numarasi"] = 3;
    body["iha_enlem"]  = vehicle->latitude();
    body["iha_boylam"] = vehicle->longitude();

    if (vehicle->altitudeRelative()) {
        body["iha_irtifa"] =
            vehicle->altitudeRelative()->rawValue().toDouble();
    }

    if (vehicle->heading()) {
        body["iha_yonelme"] =
            vehicle->heading()->rawValue().toDouble();
    }

    if (vehicle->groundSpeed()) {
        body["iha_hiz"] =
            vehicle->groundSpeed()->rawValue().toDouble();
    }

    if (vehicle->pitch()) {
        body["iha_dikilme"] = vehicle->pitch()->rawValue().toDouble();
    }

    if (vehicle->roll()) {
        body["iha_yatis"] = vehicle->roll()->rawValue().toDouble();
    }

    QmlObjectListModel* batteries = vehicle->batteries();
    QObject* obj = batteries->get(0);
    QVariant percentVariant = obj->property("percentRemaining");
    Fact* percentFact = percentVariant.value<Fact*>();
    double pct = percentFact->rawValue().toDouble();
    body["iha_batarya"] = pct;

    bool autonomous = false;
    // flightMode() typically returns a string like "AUTO", "GUIDED", etc.
    QString fm = vehicle->flightMode();
    if (!fm.isEmpty()) {
        QString up = fm.toUpper();
        if (up.contains("AUTO") || up.contains("GUIDED")) autonomous = true;
    }
    body["iha_otonom"] = autonomous ? 1 : 0;

    /*  NOT implemented - PLACEHOLDER
    int kilitlenme_val = 0;
    if (vehicle->parameterManager()) {
        auto p1 = vehicle->parameterManager()->getParameter(vehicle->defaultComponentId(), "KILITLENME");
        auto p2 = vehicle->parameterManager()->getParameter(vehicle->defaultComponentId(), "iha_kilitlenme");
        if (p1) kilitlenme_val = p1->rawValue().toInt();
        else if (p2) kilitlenme_val = p2->rawValue().toInt();
    }
    body["iha_kilitlenme"] = kilitlenme_val;
    TODO hedef
            "hedef_merkez_X":
            "hedef_merkez_Y":
            "hedef_genislik":
            "hedef_yukseklik":
    */

    QTime t = QTime::currentTime();
    QJsonObject gps;
    gps["saat"] = t.hour();
    gps["dakika"] = t.minute();
    gps["saniye"] = t.second();
    gps["milisaniye"] = t.msec();
    body["gps_saati"] = gps;

    requestJson(
        QNetworkAccessManager::PostOperation,
        "/api/telemetri_gonder",
        &body,
        [this](const QJsonObject& obj)
        {
            if (!obj.contains("konum_bilgileri")) return;

            QSet<int> seen;
            for (const auto& v : obj["konum_bilgileri"].toArray()) {
                QJsonObject o = v.toObject();
                int id = o["takim_numarasi"].toInt();
                seen.insert(id);

                _telemPlaneDataModel.updateAircraft(
                    id,
                    QGeoCoordinate(
                        o["iha_enlem"].toDouble(),
                        o["iha_boylam"].toDouble()
                    ),
                    o["iha_yonelme"].toDouble(),
                    o["iha_irtifa"].toDouble(),
                    o["iha_hizi"].toDouble()
                );
            }
            _telemPlaneDataModel.removeAircraftNotIn(seen);
        }
    );
}

bool ServerManager::telemRunning() const
{
    return _telemTimer && _telemTimer->isActive();
}

void ServerManager::toggleTelem()
{
    _telemElapsedTimer.invalidate();
    telemRunning() ? _telemTimer->stop()
                   : _telemTimer->start();

    emit telemRunningChanged();
}

/* ========================================================================== *
 * Log Buffer Management (QML-facing)                                         *
 * ========================================================================== */

void ServerManager::appendLog(const QString& line)
{
    _logs.append(line);

    if (_logs.size() > 1000)
        _logs.removeFirst();

    emit logsChanged();
}

void ServerManager::clearLogs()
{
    _logs.clear();
    emit logsChanged();
}

void ServerManager::setCompetitionField(const QVariantList& coords)
{
    _competitionField.clear();

    for (const QVariant& v : coords) {
        if (v.canConvert<QGeoCoordinate>()) {
            _competitionField.append(v);
        }
    }

    emit competitionFieldChanged();
}

void ServerManager::clearCompetitionField()
{
    _competitionField.clear();
    emit competitionFieldChanged();
}

static bool validateHssObject(
    const QJsonObject& o,
    QString* errorOut = nullptr)
{
    struct Key {
        const char* name;
        QJsonValue::Type type;
    };

    static const Key requiredKeys[] = {
        { "id",          QJsonValue::Double },
        { "hssEnlem",    QJsonValue::Double },
        { "hssBoylam",   QJsonValue::Double },
        { "hssYaricap",  QJsonValue::Double }
    };

    for (const Key& k : requiredKeys) {
        if (!o.contains(k.name)) {
            if (errorOut)
                *errorOut = QString("HSS entry missing key: %1").arg(k.name);
            return false;
        }

        if (o[k.name].type() != k.type) {
            if (errorOut)
                *errorOut = QString(
                    "HSS key '%1' has wrong type"
                ).arg(k.name);
            return false;
        }
    }

    return true;
}

void ServerManager::getHSS()
{
    requestJson(
        QNetworkAccessManager::GetOperation,
        "/api/hss_koordinatlari",
        nullptr,
        [this](const QJsonObject& obj)
        {
            if (!obj.contains("hss_koordinat_bilgileri") ||
                !obj["hss_koordinat_bilgileri"].isArray()) {
                emit errorOccurred("error getting HSS","Invalid HSS payload");
                return;
            }

            _hssList.clear();

            QJsonArray arr = obj["hss_koordinat_bilgileri"].toArray();
            if (arr.isEmpty()) {emit errorOccurred("Warning\n getting HSS","Server returned empty HSS list"); emit hssListChanged(); return;}
            for (const QJsonValue& v : arr) {
                if (!v.isObject()) {
                    emit errorOccurred("Error getting HSS", "Invalid HSS entry (not object)");
                    continue;
                }
                QJsonObject o = v.toObject();

                QString validationError;
                if (!validateHssObject(o, &validationError)) {
                    emit errorOccurred(
                        "Error getting HSS",
                        validationError
                    );
                    continue;
                }

                QVariantMap hss;
                hss["center"] = QVariant::fromValue(
                    QGeoCoordinate(
                        o["hssEnlem"].toDouble(),
                        o["hssBoylam"].toDouble()
                    )
                );
                hss["radius"] = o["hssYaricap"].toDouble();
                hss["id"]     = o["id"].toInt();

                _hssList.append(hss);
            }

            emit hssListChanged();
        }
    );
}
