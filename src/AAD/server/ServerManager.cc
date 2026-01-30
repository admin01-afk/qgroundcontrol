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

    // Telemetry loop (2 Hz)
    _telemTimer = new QTimer(this);
    _telemTimer->setInterval(500);
    connect(_telemTimer, &QTimer::timeout,
            this, &ServerManager::_telemLoop);

    // Prevent stray server processes on app exit
    connect(qApp, &QCoreApplication::aboutToQuit,
            this, &ServerManager::stopServerSim);
}

/* ============================================================================
 * HTTP / JSON Helper Utilities
 * ========================================================================== */

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
        emit errorOccurred("Unsupported HTTP operation");
        return;
    }

    connect(reply, &QNetworkReply::finished, this,
        [this, reply, onSuccess]()
        {
            const int httpStatus =
                reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

            const QByteArray data = reply->readAll();

            // Network-level error
            if (reply->error() != QNetworkReply::NoError) {
                emit errorOccurred(
                    QString("HTTP %1: %2\n%3")
                        .arg(httpStatus)
                        .arg(reply->errorString())
                        .arg(QString::fromUtf8(data))
                );
                reply->deleteLater();
                return;
            }

            // JSON parsing
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(data, &err);

            if (err.error != QJsonParseError::NoError || !doc.isObject()) {
                emit errorOccurred(
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
                emit errorOccurred("Invalid QR coordinate payload");
                return;
            }

            emit qrCoordinatesReceived(QGeoCoordinate(
                obj["qrEnlem"].toDouble(),
                obj["qrBoylam"].toDouble()
            ));
        }
    );
}

void ServerManager::checkConnection()
{
    QNetworkRequest req{ QUrl(_baseUrl) };
    req.setAttribute(QNetworkRequest::RedirectionTargetAttribute, true);

    QNetworkReply* reply = _nam->head(req);

    connect(reply, &QNetworkReply::finished,
            this, [this, reply]() {

        // Only fail on real network errors
        if (reply->error() == QNetworkReply::HostNotFoundError ||
            reply->error() == QNetworkReply::ConnectionRefusedError ||
            reply->error() == QNetworkReply::TimeoutError) {
            emit connectionResult(false);
        } else {
            emit connectionResult(true);
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

    _serversimProcess->start("python3", { script });

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
  TODO verify telem hz -> warn, clear last telem plane data from server(remove icons in map)
 * ========================================================================== */

void ServerManager::_telemLoop()
{
    appendLog("[TELEM] tick");

    QJsonObject body{
        {"takim_numarasi", 3}
        //TODO
    };

    requestJson(
        QNetworkAccessManager::PostOperation,
        "/api/telemetri_gonder",
        &body,
        [this](const QJsonObject& obj)
        {
            if (!obj.contains("konum_bilgileri")) {qDebug("no konum_bilgileri in json"); return; }

            for (const auto& v : obj["konum_bilgileri"].toArray()) {
                QJsonObject o = v.toObject();

                int teamId = o["takim_numarasi"].toInt();
                double lat = o["iha_enlem"].toDouble();
                double lon = o["iha_boylam"].toDouble();
                double heading = o["iha_yonelme"].toDouble(0.0);  // Default to 0 if not present
                double alt = o["iha_irtifa"].toDouble();
                double speed = o["iha_hizi"].toDouble();

                _telemPlaneDataModel.updateAircraft(
                    teamId,
                    QGeoCoordinate(lat, lon),
                    heading,
                    alt,
                    speed
                );
            }
        }
    );
}

bool ServerManager::telemRunning() const
{
    return _telemTimer && _telemTimer->isActive();
}

void ServerManager::toggleTelem()
{
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
                emit errorOccurred("Invalid HSS payload");
                return;
            }

            _hssList.clear();

            QJsonArray arr = obj["hss_koordinat_bilgileri"].toArray();
            for (const QJsonValue& v : arr) {
                QJsonObject o = v.toObject();

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
