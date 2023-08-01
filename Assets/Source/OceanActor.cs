using System;
using System.Collections;
using System.Collections.Generic;
using JetBrains.Annotations;
using Ocean;
using UnityEngine;
using Random = UnityEngine.Random;

public class OceanActor : MonoBehaviour
{
	public enum ESpreadingModelType
	{
		None,
		PlainDirectional,
		DonelanBannerDirectional,
	}

	ESpreadingModelType SpreadingModelType = ESpreadingModelType.PlainDirectional;
	
	public int MeshSize = 256;

	public int HalfMeshSize => MeshSize >> 1;
	
    public float DomainSize = 10;
	
    public float A = 10.0f;
    
    public float WindScale = 2;     //风强

    public float HeightScale = 1;

    public float HorizontalScale = 1;
    
    public float TimeScale = 1;     //时间影响

    public float WindSpeed = 10.0f;

    public float WindAngle = 45;

    public float DirDepend = 0.07f;

    public Vector4 WindAndSeed = new Vector4(1.0f, 1.0f, 0.0f, 0.0f);
	
    private float _totalRuntimeTime = 0.0f;

    public ComputeShader OceanComputeShader;
    
    public Material OceanMaterial;  //渲染海洋的材质

    private Mesh _mesh;
    
    private MeshFilter _filter;
    
    private MeshRenderer _render;
    
    private int[] _vertIndices;		
    private Vector3[] _positions;   
    private Vector2[] _uvs;
	
    [SerializeField]
    private RenderTexture _gaussianRandomRT;

    [SerializeField]
    private RenderTexture _heightSpectrumRT;
    
    [SerializeField]
    private RenderTexture _horizontalSpectrumRT0;

    [SerializeField] 
    private RenderTexture _horizontalSpectrumRT1;

    [SerializeField]
    private RenderTexture _heightFieldRT;
	
    [SerializeField]
    private RenderTexture _horizontalFieldRT0;

    [SerializeField]
    private RenderTexture _horizontalFieldRT1;
	    
    [SerializeField]
    private RenderTexture _fftInRT;
    
    [SerializeField]
    private RenderTexture _fftOutRT;
	
    [SerializeField]
    private RenderTexture _displacementFieldRT;

    [SerializeField] 
    private RenderTexture _oceanNormalRT;

    private int _kerCalculateGaussianNoise;
    private int _kerUpdateHeightSpectrum;
    private int _kerUpdateHorizontalSpectrum;
    private int _kerHorizontalFFT;
    private int _kerVerticalFFT;
    private int _kerCalculateDisplacementField;
    private int _kerCalculateNormalAndBubbles;

    private int _fftPower = 0;

    private void Awake()
    {
	    //添加网格及渲染组件
	    _filter = gameObject.GetComponent<MeshFilter>();
	    if (_filter == null)
	    {
		    _filter = gameObject.AddComponent<MeshFilter>();
	    }
	    _render = gameObject.GetComponent<MeshRenderer>();
	    if (_render == null)
	    {
		    _render = gameObject.AddComponent<MeshRenderer>();
	    }
	    
	    _mesh = new Mesh();
	    _filter.mesh = _mesh;
	    _render.material = OceanMaterial;
    }

    // Start is called before the first frame update
    void Start()
    {
        CreateMesh();

        Init();
    }

    // Update is called once per frame
    void Update()
    {
        UpdateOcean();
    }
    
    private void Init()
    {
	    _fftPower = (int)Mathf.Log(MeshSize, 2.0f);

	    if (_gaussianRandomRT != null && _gaussianRandomRT.IsCreated())
	    {
		    _gaussianRandomRT.Release();
		    
		    _heightSpectrumRT.Release();
		    _horizontalSpectrumRT0.Release();
		    _horizontalSpectrumRT1.Release();
		    
		    _heightFieldRT.Release();
		    _horizontalFieldRT0.Release();
		    _horizontalFieldRT1.Release();
		    
		    _fftInRT.Release();
		    _fftOutRT.Release();
		    _displacementFieldRT.Release();
	    }

	    _gaussianRandomRT = RenderHelper.CreateRT(MeshSize, RenderTextureFormat.RGFloat);
		
	    _heightSpectrumRT = RenderHelper.CreateRT(MeshSize, RenderTextureFormat.RGFloat);
	    _horizontalSpectrumRT0 = RenderHelper.CreateRT(MeshSize, RenderTextureFormat.RGFloat);
	    _horizontalSpectrumRT1 = RenderHelper.CreateRT(MeshSize, RenderTextureFormat.RGFloat);
	    
	    _heightFieldRT = RenderHelper.CreateRT(MeshSize, RenderTextureFormat.RGFloat);
	    _horizontalFieldRT0 = RenderHelper.CreateRT(MeshSize, RenderTextureFormat.RGFloat);
	    _horizontalFieldRT1 = RenderHelper.CreateRT(MeshSize, RenderTextureFormat.RGFloat);
	  
	    _fftInRT = RenderHelper.CreateRT(MeshSize, RenderTextureFormat.RGFloat);
	    _fftOutRT = RenderHelper.CreateRT(MeshSize, RenderTextureFormat.RGFloat);
	    _displacementFieldRT = RenderHelper.CreateRT(MeshSize, RenderTextureFormat.ARGBFloat);
	    _oceanNormalRT = RenderHelper.CreateRT(MeshSize, RenderTextureFormat.ARGBFloat);
	    
	    _kerCalculateGaussianNoise = OceanComputeShader.FindKernel("CalculateGaussianNoise");
	    _kerUpdateHeightSpectrum = OceanComputeShader.FindKernel("UpdateHeightSpectrum");
	    _kerUpdateHorizontalSpectrum = OceanComputeShader.FindKernel("UpdateHorizontalSpectrum");
	    
	    _kerHorizontalFFT = OceanComputeShader.FindKernel("HorizontalFFT");
	    _kerVerticalFFT = OceanComputeShader.FindKernel("VerticalFFT");
	    _kerCalculateDisplacementField = OceanComputeShader.FindKernel("CalculateDisplacementField");
	    _kerCalculateNormalAndBubbles = OceanComputeShader.FindKernel("CalculateNormalAndBubbles");
	    
	    OceanComputeShader.SetInt("N", MeshSize);
	    OceanComputeShader.SetFloat("domainSize", DomainSize);

	    OceanComputeShader.SetFloat("heightScale", HeightScale);
	    OceanComputeShader.SetFloat("horizontalScale", HorizontalScale);
	    
	    OceanComputeShader.SetTexture(_kerCalculateGaussianNoise, "GaussianNoiseTexture", _gaussianRandomRT);
	    
	    OceanComputeShader.Dispatch(_kerCalculateGaussianNoise,
		    MeshSize / 32, MeshSize / 32, 1);
    }

    private void UpdateOcean()
    {
	    _totalRuntimeTime += Time.deltaTime * TimeScale;
	    
	    UpdateHeightSpectrum();
	    UpdateHorizontalSpectrum();
	    
	    UpdateDisplacementField();
	    UpdateNormalAndBubbles();
	    
	    UpdateOceanMaterial();
    }

    private void UpdateOceanMaterial()
    {
	    OceanMaterial.SetTexture("_Displace", _displacementFieldRT);
	    OceanMaterial.SetTexture("_Normal",_oceanNormalRT);
    }

    private void ComputeFFT(ref RenderTexture rtIn, ref RenderTexture rtOut)
    {
	    Graphics.CopyTexture(rtIn,_fftInRT);
		
	    for (int i = 0; i < _fftPower; i++)
	    {
		    OceanComputeShader.SetInt("Ns", (int)Mathf.Pow(2, i));
		    OceanComputeShader.SetTexture(_kerHorizontalFFT, "fftIn", _fftInRT);
		    OceanComputeShader.SetTexture(_kerHorizontalFFT, "fftOut", _fftOutRT);
			
		    OceanComputeShader.Dispatch(_kerHorizontalFFT, MeshSize / 32, MeshSize / 32, 1);
			
		    //交换输入输出纹理
		    Graphics.CopyTexture(_fftOutRT,_fftInRT);
	    }
		
	    // Vertical FFT
	    for (int i = 0; i < _fftPower; i++)
	    {
		    OceanComputeShader.SetInt("Ns", (int)Mathf.Pow(2, i));
		    OceanComputeShader.SetTexture(_kerVerticalFFT, "fftIn", _fftInRT);
		    OceanComputeShader.SetTexture(_kerVerticalFFT, "fftOut", _fftOutRT);
			
		    OceanComputeShader.Dispatch(_kerVerticalFFT, MeshSize / 32, MeshSize / 32, 1);
			
		    Graphics.CopyTexture(_fftOutRT,_fftInRT);
	    }

	    Graphics.CopyTexture(_fftInRT, rtOut);
    }
    
    private void ComputeHeightField()
    {
	    ComputeFFT(ref _heightSpectrumRT,ref _heightFieldRT);
    }

    private void ComputeHorizontalField()
    {
	    ComputeFFT(ref _horizontalSpectrumRT0, ref _horizontalFieldRT0);
	    ComputeFFT(ref _horizontalSpectrumRT1, ref _horizontalFieldRT1);
    }

    private void UpdateNormalAndBubbles()
    {
	    OceanComputeShader.SetTexture(_kerCalculateNormalAndBubbles, "displacementField", _displacementFieldRT);
	    OceanComputeShader.SetTexture(_kerCalculateNormalAndBubbles, "oceanNormalRT", _oceanNormalRT);
	    OceanComputeShader.Dispatch(_kerCalculateNormalAndBubbles, MeshSize / 32, MeshSize / 32, 1);
    }

    private void UpdateDisplacementField()
    {
		ComputeHeightField();
		ComputeHorizontalField();
		
		// Scale And Get Height Field
		OceanComputeShader.SetTexture(_kerCalculateDisplacementField, "heightField", _heightFieldRT);
		OceanComputeShader.SetTexture(_kerCalculateDisplacementField, "horizontalField0", _horizontalFieldRT0);
		OceanComputeShader.SetTexture(_kerCalculateDisplacementField, "horizontalField1", _horizontalFieldRT1);
		OceanComputeShader.SetTexture(_kerCalculateDisplacementField, "displacementField", _displacementFieldRT);
		
		OceanComputeShader.Dispatch(_kerCalculateDisplacementField, MeshSize / 32, MeshSize / 32, 1);
    }

    private void UpdateHorizontalSpectrum()
    {
	    OceanComputeShader.SetTexture(_kerUpdateHorizontalSpectrum, "HeightSpectrumTexture", _heightSpectrumRT);
	    OceanComputeShader.SetTexture(_kerUpdateHorizontalSpectrum, "HorizontalSpectrumTexture0", _horizontalSpectrumRT0);
	    OceanComputeShader.SetTexture(_kerUpdateHorizontalSpectrum, "HorizontalSpectrumTexture1", _horizontalSpectrumRT1);

	    OceanComputeShader.Dispatch(_kerUpdateHorizontalSpectrum, MeshSize / 32, MeshSize / 32, 1);
    }

    private void UpdateHeightSpectrum()
    {
	    float windDirRadian = Mathf.Deg2Rad * WindAngle;
	    
	    WindAndSeed.z = Random.Range(1, 10f);
	    WindAndSeed.w = Random.Range(1, 10f);
	    Vector2 wind = new Vector2(WindAndSeed.x, WindAndSeed.y);
	    wind.Normalize();
	    wind *= WindScale;
	    
	    OceanComputeShader.SetFloat("A", A);
	    OceanComputeShader.SetInt("spreadingModelType", 2);
	    OceanComputeShader.SetFloat("windDirRadian", windDirRadian);
	    OceanComputeShader.SetFloat("windSpeed", WindSpeed);
	    OceanComputeShader.SetFloat("dirDepend", DirDepend);
	    OceanComputeShader.SetFloat("time", _totalRuntimeTime);
	    OceanComputeShader.SetVector("windAndSeed", new Vector4(wind.x, wind.y, WindAndSeed.z, WindAndSeed.w));
		
	    OceanComputeShader.SetTexture(_kerUpdateHeightSpectrum, "GaussianNoiseTexture", _gaussianRandomRT);
	    OceanComputeShader.SetTexture(_kerUpdateHeightSpectrum, "HeightSpectrumTexture", _heightSpectrumRT);

	    OceanComputeShader.Dispatch(_kerUpdateHeightSpectrum, 
		    MeshSize / 32, MeshSize / 32, 1);
    }

    private void CreateMesh()
    {
	    _vertIndices = new int[(MeshSize - 1) * (MeshSize - 1) * 6];
	    _positions = new Vector3[MeshSize * MeshSize];
	    _uvs = new Vector2[MeshSize * MeshSize];

	    int inx = 0;
	    for (int i = 0; i < MeshSize; i++)
	    {
		    for (int j = 0; j < MeshSize; j++)
		    {
			    int index = i * MeshSize + j;
			    _positions[index] = new Vector3((j - MeshSize / 2.0f) * DomainSize / MeshSize, 0, (i - MeshSize / 2.0f) * DomainSize / MeshSize);
			    _uvs[index] = new Vector2(j / (MeshSize - 1.0f), i / (MeshSize - 1.0f));

			    if (i != MeshSize - 1 && j != MeshSize - 1)
			    {
				    _vertIndices[inx++] = index;
				    _vertIndices[inx++] = index + MeshSize;
				    _vertIndices[inx++] = index + MeshSize + 1;

				    _vertIndices[inx++] = index;
				    _vertIndices[inx++] = index + MeshSize + 1;
				    _vertIndices[inx++] = index + 1;
			    }
		    }
	    }
	    _mesh.vertices = _positions;
	    _mesh.SetIndices(_vertIndices, MeshTopology.Triangles, 0);
	    _mesh.uv = _uvs;
    }
}
