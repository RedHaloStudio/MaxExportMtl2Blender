bl_info = {  
    "name": "Red Halo Tools",  
    "author": "Red Halo Studio",  
    "version": (0, 1),  
    "blender": (2, 80, 0),  
    "location": "View 3D > Tools > Red Halo Tools",  
    "description": "",  
    "wiki_url": "",  
    "tracker_url": "",  
    "category": "Tools"
 }

import bpy
from .tools_panel import VIEW3D_PT_RedHaloTools
from .import_mtl import Tools_OT_loadMaterials
from .set_color_id import Tools_OT_setColorID
 
classes = (
    Tools_OT_loadMaterials,
    Tools_OT_setColorID,
    VIEW3D_PT_RedHaloTools
)

def register():
    for cls in classes:
        bpy.utils.register_class(cls)


def unregister():
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)