/****************************************************************************
**
** SPDX-License-Identifier: GPL-3.0-or-later
**
****************************************************************************/

#ifndef SSCACCELEROMETERADAPTORPLUGIN_H
#define SSCACCELEROMETERADAPTORPLUGIN_H

#include "plugin.h"

class SscAccelerometerAdaptorPlugin : public Plugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "com.nokia.SensorService.Plugin/1.0")

private:
    void Register(class Loader &l);
};

#endif
