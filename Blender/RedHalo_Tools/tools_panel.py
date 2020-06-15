import bpy
from bpy.types import Operator

class VIEW3D_PT_RedHaloTools(bpy.types.Panel):
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'Tool'    
    bl_label = "RED HALO Tools"

    def draw(self, context): 
             
        layout = self.layout

        row = layout.column(align=True)
        row.scale_y = 1.5
        row.operator('redhalo.load_material', icon='IMPORT',text = "LOAD Material")
        row.operator('redhalo.set_color_id', icon='IMPORT',text = "Set Color ID")