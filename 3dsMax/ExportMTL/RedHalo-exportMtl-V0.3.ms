macroScript Export_Tools
	category:"Red Halo"
	toolTip:"Export MTL"
(

    try(DestroyDialog exportMtl)catch()

    global mtl_name_list = #()
    global mtl_list = #()
    all_mat_name = #()

	--把RGB转换为浮点型
    fn convertColor2Float clr =
    (
        ss = StringStream ""
        format "%,%,%,1.00" ((clr.r/255.0) as string) ((clr.g/255.0) as string) ((clr.b/255.0) as string) to:ss
        
        return (ss as string)
    )

    --格式化路径
    fn normalPath path =
    (
        newpath = ""

        if doesFileExist path then
        (
            list = FilterString path "\\"
            for i = 1 to list.count do
            (
                
                if i != list.count then
                (
                    newpath += list[i] + "/"
                )else(
                    newpath += list[i]
                )
            )
        )else(
            --newPath = "undefined"
        )
        return newpath
    )

    Struct NewtonJson
    (
        fn init = (
            jsondll = (getDir #scripts) + "\\ExportMTL\\Newtonsoft.Json.dll"--@"D:\Newtonsoft.Json.dll"
            
            if (dotNet.loadAssembly  jsondll)== undefined then (
                messageBox "Could not find or load Newtonsoft.Json.dll."
            ) else (
                --format "loadDLL:%" jsondll
            )
        ),

        fn new = (
            local jobj=dotNetObject "Newtonsoft.Json.Linq.JObject"
            return jobj
        ),

        fn newArray = (
            local JsonObject = dotNetObject "Newtonsoft.Json.Linq.Jarray"
        ),

        fn addProp jsonObject key value = (
            Jprop = dotNetObject "Newtonsoft.Json.Linq.JProperty" key value
            JsonObject.add JProp
        ),

        fn appendJarray jarray val = (
            Jarray.add val
        ),
        fn array2Json mxsArray = (
            local JArray = this.newArray()

            for i = 1 to mxsArray.count do (
                item = mxsAraay[i]
                newtonjson.appendJarray JArray item
            )
        ),
        on create do this.init()
    )
	
    fn getMixTex orig =
    (
        mixMap1_Clr = convertColor2Float orig.color1
        mixMap2_Clr = convertColor2Float orig.color2
        try(mixMap1 = normalPath orig.map1.filename)catch(mixMap1 = "undefined")
        try(mixMap2 = normalPath orig.map2.filename)catch(mixMap2 = "undefined")
        mixMask_value = (orig.mixAmount / 100.0) as string
        try(mixMask_Map = normalPath orig.mask.filename) catch ( mixMask_Map = "undefined")

        return #(mixMap1_Clr, mixMap1, mixMap2_Clr, mixMap2, mixMask_Value, mixMask_Map)
    )

    fn getBrickTex orig =
    (
        brickMap1_clr = convertColor2Float orig.Brick_color
        try( brickMap1_Map = normalPath orig.Bricks.filename ) catch ( brickMap1_Map = "undefined" )
        brickMap2_clr = convertColor2Float orig.Mortar_color
        try( brickMap2_Map = normalPath orig.Mortar_Map.filename ) catch ( brickMap2_Map = "undefined" )

        return #(brickMap1_clr, brickMap1_Map, brickMap2_clr, brickMap2_Map)
    )

    fn getCheckerTex orig = (
        CheckerMap1_clr = convertColor2Float orig.color1
        CheckerMap2_clr = convertColor2Float orig.color2
        try( CheckerMap1_Map = normalPath orig.map1.filename ) catch ( CheckerMap1_Map = "undefined" )
        try( CheckerMap2_Map = normalPath orig.map2.filename ) catch ( CheckerMap2_Map = "undefined" )
        
        return #(CheckerMap1_clr, CheckerMap1_Map, CheckerMap2_clr, CheckerMap2_Map)
    )

    fn getParams mtl option = (
        json = NewtonJson()
        j = json.new()
        
        texMapArr = #()
        case classof mtl of
        (
            VrayMtl:
            (
                case option of(
                    "Diffuse":(
                        baseColor = convertColor2Float (getProperty mtl #diffuse)
                        prop = #texmap_diffuse
                    )
                    "Reflection": (
                        baseColor = ((getProperty mtl #reflection).value / 255.0) as string

                        prop = #texmap_reflection
                    )
                    "Glossiness": (  
                        baseColor = getProperty mtl #reflection_Glossiness as string
                        prop = #texmap_reflectionGlossiness
                    )
                    "Refraction": (                   
                        baseColor = ((getProperty mtl #Refraction).value / 255.0) as string
                        prop = #texmap_refraction
                    )
                    "RefractionGlossiness": (                   
                        baseColor = (1- (getProperty mtl #refraction_glossiness) as string)
                        prop = #texmap_refractionGlossiness
                    )
                    "Metallic": (                   
                        baseColor = getProperty mtl #reflection_metalness as string
                        prop = #texmap_metalness
                    )
                    "IOR": (                   
                        baseColor = getProperty mtl #refraction_ior as string

                        prop = #texmap_refractionIOR
                    )
                    "Alpha": (                   
                        baseColor = "1"

                        prop = #texmap_opacity
                    )
                    "Bump": (                   
                        baseColor = "1"

                        prop = #texmap_bump
                    )
                    "Emission": ( 
                        baseColor = convertColor2Float (getProperty mtl #selfIllumination)
                        baseMulti = (getProperty mtl #selfIllumination_multiplier)  as string
                                            
                        prop = #texmap_self_illumination
                    )
                )

                try(texMap = getProperty mtl prop)catch()
                if texMap != undefined then (
                    case classof texMap of
                    (
                        Mix: (
                            TexType = "Mix"
                            texMapArr = getMixTex texMap
                        )
                        Bricks: (
                            TexType = "Bricker"
                            texMapArr = getBrickTex texMap
                        )
                        Checker: (
                            TexType = "Checker"
                            texMapArr = getCheckerTex texMap
                        )
                        Bitmaptexture: (
                            TexType = "Bitmap"
							f = normalPath texMap.filename
                            texMapArr = #( f)
                        )
                        default: (
                            Textype = "undefined"
                            texMapArr = #()
                        )
                    )
                ) else (
                    TexType = "undefined"
                    texMapArr = #()
                )
                
                json.addProp j "Color" baseColor
                if option == "Emission"  do json.addProp j "Multiplier" baseMulti
                if TexType != "undefined" do (
                    json.addProp j "TexmapType" TexType
                    json.addProp j "TexmapProps" #(texMapArr)
                )
            )
            
            VrayLightMtl:
            (
                case option of(
                    "Color":
                    (
                        baseColor = convertColor2Float (getProperty mtl #color)

                        prop = #texmap
                        
                    )
                    "Multiplier":
                    (
                        prop_clr = #Multiplier
                        baseMulti = (getProperty mtl prop_clr) as string

                        json.addProp j "Multiplier" baseMulti
                    )
                    "Opacity":
                    (
                        --prop_clr = #color
                        --baseColor = convertColor2Float (getProperty mtl prop_clr)

                        prop = #opacity_texmap
                    )
                )

                --print prop
                try(texMap = getProperty mtl prop)catch()
                if texMap != undefined then (
                    case classof texMap of
                    (
                        Mix: (
                            TexType = "Mix"
                            texMapArr = getMixTex texMap
                        )
                        Bricks: (
                            TexType = "Bricker"
                            texMapArr = getBrickTex texMap
                        )
                        Checker: (
                            TexType = "Checker"
                            texMapArr = getCheckerTex texMap
                        )
                        Bitmaptexture: (
                            TexType = "Bitmap"
                            texMapArr = #(normalPath texMap.filename)
                        )
                    )
                ) else (
                    TexType = "undefined"
                    texMapArr = #()
                )

                case option of(
                    "Color":(
                        json.addProp j "Color" baseColor
                        if TexType != "undefined" do (
                            json.addProp j "TexmapType" TexType
                            json.addProp j "TexmapProps" #(texMapArr)
                        )
                    )
                    "Opacity":(
                        if TexType != "undefined" do (
                            json.addProp j "TexmapType" TexType
                            json.addProp j "TexmapProps" #(texMapArr)
                        )
                    )
                    
                )
			)
        )

        
        j
    )

    fn F_NameCompare s1 s2 = stricmp s1.name s2.name

    --Collect All scene material
    fn collectMat = (
        mat = #()
        for x in objects do
        (
            if (findItem mat x.material) == 0 and x.material != undefined do append mat x.material
        )
        qsort mat F_NameCompare
        return mat
    )

    fn getAllMat mtl = (
        mtlType = classof mtl

        case mtlType of
        (
            MultiMaterial:
            (
                for m = 1 to mtl.numsubs do
                (
                    getAllMat mtl[m]
                )
            )
            Vray2SideMtl:
            (
                if mtl.fontMtl != undefined do getAllMat mtl.frontMtl
                if mtl.backMtl != undefined do getAllMat mtl.backMtl
            )
            default:
                append mtl_list mtl
        )
    )

    fn setName mtl=
    (
        if (appendIfUnique all_mat_name mtl.name) == false do (
            mtl.name = mtl.name + "-D"
            setName mtl
        )
    )

    function simplyMtlName =
    (
        mats = #()
        all_mat_name = #()
        for matClass in material.classes do
        (
            for m in (getclassinstances matClass processChildren:true) do append mats m
        )
        
        for mat in mats do
        (
            try(mat.name = substituteString mat.name " " "_")catch()
            try(mat.name = substituteString mat.name "-" "_")catch()
            try(mat.name = substituteString mat.name "#" "-")catch()

            setName mat
        )
    )

    --整理场景中的纹理
    fn simplyTex node =
    (
        try( nodeType = classof node ) catch ()

        case nodeType of
        (
            Color_Correction:
                return (simplyTex node.map)
            CompositeTexturemap:
                return (simplyTex node.maplist[1])
            falloff:
                return (simplyTex node.map1)
            Output:
                return (simplyTex node.map1)
            RGB_Multiply:
                return (simplyTex node.map1)
            VrayDirt:
                return (simplyTex node.texmap_unoccluded_color)
            VRayNormalMap:
                return (simplyTex node.normal_map)
            VRayColor2Bump:
                return (simplyTex node.map)
            VRayTriplanarTex:
                return (simplyTex node.texture)
            CoronaColorCorrect:
                return (simplyTex node.inputTexmap)
            CoronaAO:
                return (simplyTex node.colorUnoccluded)
            CoronaNormal:
                return (simplyTex node.normalMap)
            Bitmaptexture:
                return node
            default:
                return node
        )	
    )

    --整理所有材质
    fn simplyMat mat =
    (
        --整理场景材质
        matType = classof mat
        case matType of
        (
            VrayMtl:
            (
                
                if classof mat.texmap_diffuse == VrayColor do (
                    mat.diffuse = mat.texmap_diffuse.color
                    mat.texmap_diffuse = undefined
                )
                mat.texmap_diffuse = simplyTex mat.texmap_diffuse
                mat.texmap_reflection = simplyTex mat.texmap_reflection
                mat.texmap_reflectionGlossiness = simplyTex mat.texmap_reflectionGlossiness
                mat.texmap_refraction = simplyTex mat.texmap_refraction
                mat.texmap_refractionGlossiness = simplyTex mat.texmap_refractionGlossiness
                mat.texmap_metalness = simplyTex mat.texmap_metalness
                mat.texmap_refractionIOR  = simplyTex mat.texmap_refractionIOR 
                mat.texmap_opacity  = simplyTex mat.texmap_opacity 
                mat.texmap_bump = simplyTex mat.texmap_bump
                mat.texmap_self_illumination = simplyTex mat.texmap_self_illumination
            )
            Standardmaterial:
            (
                mat.diffuseMap = simplyTex mat.diffuseMap
                mat.reflectionMap = simplyTex mat.reflectionMap
                mat.refractionMap = simplyTex mat.refractionMap
                mat.glossinessMap = simplyTex mat.glossinessMap
                mat.bumpMap = simplyTex mat.bumpMap
                mat.opacityMap = simplyTex mat.opacityMap
            )
            CoronaMtl:
            (
                mat.texmapDiffuse = simplyTex mat.texmapDiffuse
                mat.texmapReflect = simplyTex mat.texmapReflect
                mat.texmapReflectGlossiness = simplyTex mat.texmapReflectGlossiness
                mat.texmapRefract = simplyTex mat.texmapRefract
                mat.texmapRefractGlossiness = simplyTex mat.texmapRefractGlossiness
                mat.texmapBump = simplyTex mat.texmapBump
                mat.texmapOpacity = simplyTex mat.texmapOpacity
                mat.texmapIor = simplyTex mat.texmapIor
                mat.texmapSelfIllum = simplyTex mat.texmapSelfIllum
            )
            VRayLightMtl:
            (
                mat.texmap = simplyTex mat.texmap
                mat.opacity_texmap = simplyTex mat.opacity_texmap
            )
            CoronaLightMtl:
            (
                mat.texmap = simplyTex mat.texmap
                mat.opacityTexmap = simplyTex mat.opacityTexmap
            )
            MultiMaterial:
            (
                for i = 1 to mat.numsubs do
                (
                    simplyMat mat[i]
                )
            )
        )
    )

    fn changeMtlType obj =
    (
        mat = obj.mat
        try(mtlType = classof mat)catch()

        case mtlType of
        (
            Vray2SidedMtl:
            (
                _t = mat.name
                obj.mat = mat.frontMtl
                obj.mat.name = _t
            )
            TopBottom:
            (
                _t = mat.name    
                obj.mat = mat.top
                obj.mat.name = _t
            )
            VRayBlendMtl:
            (
                _t = mat.name 
                obj.mat = mat.baseMtl
                _t = mat.name
            )
            VRayOverrideMtl:
            (
                _t = mat.name 
                obj.mat = mat.baseMtl
                mat.name = _t
            )
            Shell_Material:
            (
                _t = mat.name 
                obj.mat = mat.originalMaterial
                mat.name = _t
            )
            DoubleSided:
            (
                _t = mat.name 
                obj.mat = mat.material1
                mat.name = _t
            )
            CoronaLayeredMtl:
            (
                _t = mat.name 
                obj.mat = mat.baseMtl
                mat.name = _t
            )
            MultiMaterial:
            (
                for x = 1 to mat.numsubs do
                (
                    subType = classof mat[x]
                    if subType == VrayOverrideMtl or subType == CoronaLayeredMtl or subType == VRayBlendMtl do
                    (
                            obj.mat[x] = obj.mat[x].baseMtl
                    )

                    if subType == Vray2SidedMtl do obj.mat[x] = obj.mat[x].frontMtl
                    if subType == TopBottom do obj.mat[x] = obj.mat[x].top
                    if subType == Shell_Material do obj.mat[x] = obj.mat[x].originalMaterial
                    if subType == DoubleSided do obj.mat[x] = obj.mat[x].material1
                )
            )
                
        )
    )

    --查找多维子材质等下的关联材质
    fn findInstanceMat mat=
    (
        mats = getClassInstances (classof mat) target:sceneMaterials astrackviewpick:on
        m = for t in mats where t.anim == mat collect t
        return m
    )

    fn createJson mtl =(

        mtlType = "StandardMtl"

        standardMTLOptions = #("Diffuse", "Reflection", "Glossiness", "Refraction", "RefractionGlossiness", "Metallic", "IOR", "Alpha", "Bump", "Emission")
        lightMtlOptions = #("Color", "Multiplier", "Opacity")
        
        json = NewtonJson()
        parsJson = json.new()
        jsonfile = json.new()
        case classof mtl of(
            VrayLightMtl: (
                mtlType = "LightMtl"
                for i in lightMtlOptions do(                
                    p = getParams mtl i
                    json.addProp parsJson i #(p) 
                )
            )
            VrayMtl: (
                mtlType = "StandardMtl"
                for i in standardMtlOptions do(
                    
                    p = getParams mtl i
                    json.addProp parsJson i #(p) 
                )
            )
            default: mtlType = "Unkown"
        )
        json.addProp jsonfile "MaterialType" mtlType
        json.addProp jsonfile "MaterialProps" #(parsJson)
        
        return jsonfile
    )
    ---UI界面
    rollout exportMtl "Export Mtl"
    (	
        button btnMtl "导出材质列表" height:45
        button btn_help "HELP" width: 70 height:30
        button btn_test "About" width: 70 height:30

        on btn_help pressed do(
            messageBox "1.先用Vray材质转换器转换成Vray材质" title:"Red Halo Studio"
        )

        on btn_test pressed do (
            messageBox "version:0.1 @ RedHalo Studio" title:"RedHalo Studio"
        )
        
        on btnMtl pressed do
        (		
            
            filename = "BMAX_TMP_MAX.json"
			--filePath = "D:\\"
			filePath = sysInfo.tempdir
            
            filename = filePath + filename
            
            all_mat_name = #()
            
            if doesFileExist filename then
            (
                try(
                    deleteFile filename
                )catch(
                    --filename = replace filename (filename.count-3) 4 "_MTL.json"
                )
            )
            
            for o in objects do
            (
                changeMtlType o
            )

            allMats = collectMat()
            
            simplyMtlName()
            
            json = NewtonJson()
            jsonfile = json.new()
            
            root = json.new()
            for i in allMats do
            (
                --整理场景材质，去除不必要的节点
                simplyMat i
                if classof i == MultiMaterial then
                (
                    for x = 1 to i.numsubs do
                    (
                        if classof i[x] != UndefinedClass do(
                            jsonfile = createJson i[x]
                            json.addProp root i[x].name #(jsonfile)
                        )
                    )
                )else(
                    ins = findInstanceMat i
                    if ins.count < 2 do
                    (
                        jsonfile = createJson i
                        json.addProp root i.name #(jsonfile)
                    )
                )
            )
            
            str = StringStream ""
            format "%" (root.toString()) to:str
            str = str as string
            --print str
            --Write JSON
            try(
                ExportMtlFile = createfile filename encoding:#utf8 writeBOM:false 
                format "%" str to:ExportMtlFile
                close ExportMtlFile
            )catch(
                messagebox "Create File Error"
            )
        )
    )

    createdialog exportMtl width:200 pos:[100,100]
)