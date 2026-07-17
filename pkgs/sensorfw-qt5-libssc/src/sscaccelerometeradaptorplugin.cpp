/****************************************************************************
**
** SPDX-License-Identifier: GPL-3.0-or-later
**
****************************************************************************/

#include "sscaccelerometeradaptorplugin.h"
#include "sscaccelerometeradaptor.h"
#include "sensormanager.h"
#include "logging.h"

void SscAccelerometerAdaptorPlugin::Register(class Loader &)
{
    qCInfo(lcSensorFw) << "registering sscaccelerometeradaptor";
    SensorManager &sm = SensorManager::instance();
    sm.registerDeviceAdaptor<SscAccelerometerAdaptor>("accelerometeradaptor");
}
