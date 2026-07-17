/****************************************************************************
**
** sensorfw-qt5-libssc — Qualcomm SSC ALS adaptor for Sailfish
** Copyright (C) 2026 PAD6-DEV
**
** SPDX-License-Identifier: GPL-3.0-or-later
**
****************************************************************************/

#include "sscalsadaptor.h"

#include "config.h"
#include "datatypes/utils.h"

#include <QDebug>

#ifdef signals
#undef signals
#endif
#ifdef slots
#undef slots
#endif
#ifdef emit
#undef emit
#endif

extern "C" {
#include <libssc.h>
#include <glib.h>
#include <gio/gio.h>
}

void sscAlsMeasurementTrampoline(SSCSensorLight *sensor,
                                 float intensity,
                                 void *userData)
{
    Q_UNUSED(sensor);
    auto *self = static_cast<SscAlsAdaptor *>(userData);
    if (self)
        self->handleMeasurement(intensity);
}

SscAlsAdaptor::SscAlsAdaptor(const QString &id)
    : DeviceAdaptor(id)
    , buffer_(new DeviceAdaptorRingBuffer<TimedUnsigned>(32))
    , sensor_(nullptr)
    , measurementHandlerId_(0)
    , glibTimer_(nullptr)
    , sensorOpen_(false)
{
    setAdaptedSensor("als", "Qualcomm SSC ambient light (libssc)", buffer_);
    setDescription("libssc / Snapdragon Sensor Core ambient light");
    introduceAvailableInterval(DataRange(100 * 1000, 1000 * 1000, 0));
}

SscAlsAdaptor::~SscAlsAdaptor()
{
    stopAdaptor();
    delete buffer_;
}

void SscAlsAdaptor::init()
{
}

bool SscAlsAdaptor::startAdaptor()
{
    if (!glibTimer_) {
        glibTimer_ = new QTimer(this);
        connect(glibTimer_, &QTimer::timeout, this, &SscAlsAdaptor::pumpGlib);
        glibTimer_->setInterval(10);
    }
    if (!glibTimer_->isActive())
        glibTimer_->start();
    return true;
}

void SscAlsAdaptor::stopAdaptor()
{
    stopSensor();
    if (glibTimer_)
        glibTimer_->stop();
}

bool SscAlsAdaptor::startSensor()
{
    if (sensorOpen_)
        return true;

    if (!startAdaptor())
        return false;

    GError *error = nullptr;
    sensor_ = ssc_sensor_light_new_sync(nullptr, &error);
    if (!sensor_) {
        qWarning() << id() << "ssc_sensor_light_new_sync failed:"
                   << (error ? error->message : "unknown");
        if (error)
            g_error_free(error);
        return false;
    }

    measurementHandlerId_ = g_signal_connect(sensor_, "measurement",
                                             G_CALLBACK(sscAlsMeasurementTrampoline),
                                             this);

    if (!ssc_sensor_light_open_sync(sensor_, nullptr, &error)) {
        qWarning() << id() << "ssc_sensor_light_open_sync failed:"
                   << (error ? error->message : "unknown");
        if (error)
            g_error_free(error);
        if (measurementHandlerId_) {
            g_signal_handler_disconnect(sensor_, measurementHandlerId_);
            measurementHandlerId_ = 0;
        }
        g_object_unref(sensor_);
        sensor_ = nullptr;
        return false;
    }

    sensorOpen_ = true;
    qInfo() << id() << "SSC ambient light started";
    return true;
}

void SscAlsAdaptor::stopSensor()
{
    if (!sensor_)
        return;

    if (sensorOpen_) {
        GError *error = nullptr;
        ssc_sensor_light_close_sync(sensor_, nullptr, &error);
        if (error) {
            qWarning() << id() << "ssc light close:" << error->message;
            g_error_free(error);
        }
        sensorOpen_ = false;
    }

    if (measurementHandlerId_) {
        g_signal_handler_disconnect(sensor_, measurementHandlerId_);
        measurementHandlerId_ = 0;
    }
    g_object_unref(sensor_);
    sensor_ = nullptr;
    qInfo() << id() << "SSC ambient light stopped";
}

void SscAlsAdaptor::pumpGlib()
{
    GMainContext *ctx = g_main_context_default();
    while (g_main_context_pending(ctx))
        g_main_context_iteration(ctx, FALSE);
}

void SscAlsAdaptor::handleMeasurement(float intensity)
{
    TimedUnsigned *d = buffer_->nextSlot();
    d->timestamp_ = Utils::getTimeStamp();
    /* sensorfw ALS expects integer lux */
    d->value_ = intensity < 0.f ? 0u : static_cast<quint32>(intensity + 0.5f);
    buffer_->commit();
    buffer_->wakeUpReaders();
}
