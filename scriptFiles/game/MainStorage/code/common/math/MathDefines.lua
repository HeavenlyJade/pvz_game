local MathDefines = {}

MathDefines.M_EPSILON = 0.000001
MathDefines.M_PI = 3.14159265358979323846
MathDefines.M_DEGTORAD = MathDefines.M_PI / 180.0
MathDefines.M_DEGTORAD_2 = MathDefines.M_PI / 360.0
MathDefines.M_RADTODEG = 1.0 / MathDefines.M_DEGTORAD
MathDefines.Rad2Deg = 180.0 / MathDefines.M_PI
MathDefines.Deg2Rad = MathDefines.M_PI / 180.0

--朝向摄像机模式
MathDefines.FaceCameraMode = {
    FC_NONE = 0,
    FC_ROTATE_XYZ,
    FC_ROTATE_Y,
    FC_LOOKAT_XYZ,
    FC_LOOKAT_Y,
    FC_LOOKAT_MIXED,
    FC_DIRECTION,
}

return MathDefines