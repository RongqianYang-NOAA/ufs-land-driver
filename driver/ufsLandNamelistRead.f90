module NamelistRead

implicit none
save
private

type, public :: namelist_type

  character*128  :: static_file
  character*128  :: init_file
  character*128  :: forcing_dir
  character*128  :: output_dir
  
  integer        :: timestep_seconds
  
  character*19   :: simulation_start
  character*19   :: simulation_end
  integer        :: run_timesteps

  integer        :: land_model

  integer        :: run_days
  integer        :: run_hours
  integer        :: run_minutes
  integer        :: run_seconds

  integer        :: num_soil_levels
  real           :: forcing_height

  real, allocatable, dimension(:) ::  soil_level_thickness ! soil level thicknesses [m]
  real, allocatable, dimension(:) ::  soil_level_nodes     ! soil level centroids from surface [m]
  
  double precision :: initial_time

  integer        ::  dynamic_vegetation_option
  integer        ::  canopy_stomatal_resistance_option
  integer        ::  soil_wetness_option
  integer        ::  runoff_option
  integer        ::  surface_exchange_option
  integer        ::  supercooled_soilwater_option
  integer        ::  frozen_soil_adjust_option
  integer        ::  radiative_transfer_option
  integer        ::  snow_albedo_option
  integer        ::  precip_partition_option
  integer        ::  soil_temp_lower_bdy_option
  integer        ::  soil_temp_time_scheme_option
  integer        ::  surface_evap_resistance_option
  integer        ::  glacier_option

  contains

    procedure, public  :: ReadNamelist         

end type namelist_type
     
contains   

  subroutine ReadNamelist(this)
  
    use time_utilities
  
    class(namelist_type) :: this
    
    character*128  :: static_file = ""
    character*128  :: init_file = ""
    character*128  :: forcing_dir = ""
    character*128  :: output_dir = ""
  
    integer        :: timestep_seconds = -999
  
    character*19   :: simulation_start = ""
    character*19   :: simulation_end = ""

    integer        :: run_days = -999
    integer        :: run_hours = -999
    integer        :: run_minutes = -999
    integer        :: run_seconds = -999
    integer        :: run_timesteps = -999
    
    integer        :: land_model = -999

    integer        :: num_soil_levels = -999
    real           :: forcing_height = -999.

    real, allocatable, dimension(:) ::  soil_level_thickness ! soil level thicknesses [m]
    real, allocatable, dimension(:) ::  soil_level_nodes     ! soil level centroids from surface [m]
    
    double precision :: run_time = -999.d0
    
    integer        ::  dynamic_vegetation_option         = -999
    integer        ::  canopy_stomatal_resistance_option = -999
    integer        ::  soil_wetness_option               = -999
    integer        ::  runoff_option                     = -999
    integer        ::  surface_exchange_option           = -999
    integer        ::  supercooled_soilwater_option      = -999
    integer        ::  frozen_soil_adjust_option         = -999
    integer        ::  radiative_transfer_option         = -999
    integer        ::  snow_albedo_option                = -999
    integer        ::  precip_partition_option           = -999
    integer        ::  soil_temp_lower_bdy_option        = -999
    integer        ::  soil_temp_time_scheme_option      = -999
    integer        ::  surface_evap_resistance_option    = -999
    integer        ::  glacier_option                    = -999

    integer, parameter :: NOAHMP_LAND_SURFACE_MODEL = 2
  
    namelist / run_setup  / static_file, init_file, forcing_dir, output_dir, timestep_seconds, &
                            simulation_start, simulation_end, run_days, run_hours, run_minutes, &
			    run_seconds, run_timesteps
    namelist / land_model_option / land_model
    namelist / structure  / num_soil_levels, forcing_height
    namelist / soil_setup / soil_level_thickness, soil_level_nodes
    namelist / noahmp_options /                                                        &
               dynamic_vegetation_option         , canopy_stomatal_resistance_option , &
               soil_wetness_option               , runoff_option                     , &
               surface_exchange_option           , supercooled_soilwater_option      , &
               frozen_soil_adjust_option         , radiative_transfer_option         , &
               snow_albedo_option                , precip_partition_option           , &
               soil_temp_lower_bdy_option        , soil_temp_time_scheme_option      , &
               surface_evap_resistance_option    , glacier_option                    
 
!---------------------------------------------------------------------
!  read input file, part 1
!---------------------------------------------------------------------

    open(30, file="ufs-land.namelist", form="formatted")
     read(30, run_setup)
     read(30, land_model_option)
     read(30, structure)
    close(30)

    allocate (soil_level_thickness (1:num_soil_levels))   ! soil level thicknesses [m]
    allocate (soil_level_nodes     (1:num_soil_levels))   ! soil level centroids from surface [m]

!---------------------------------------------------------------------
!  read input file, part 2
!---------------------------------------------------------------------

    open(30, file="ufs-land.namelist", form="formatted")
     read(30, soil_setup)
    close(30)
    
!---------------------------------------------------------------------
!  read input file, part 3
!---------------------------------------------------------------------

    open(30, file="ufs-land.namelist", form="formatted")
     if(land_model == NOAHMP_LAND_SURFACE_MODEL) then
       read(30, noahmp_options)
     end if
    close(30)
    
!---------------------------------------------------------------------
!  transfer to structure
!---------------------------------------------------------------------

    this%land_model           = land_model
    this%static_file          = static_file
    this%init_file            = init_file
    this%forcing_dir          = forcing_dir
    this%output_dir           = output_dir
    this%timestep_seconds     = timestep_seconds
    this%simulation_start     = simulation_start
    this%simulation_end       = simulation_end
    this%run_days             = run_days
    this%run_hours            = run_hours
    this%run_minutes          = run_minutes
    this%run_seconds          = run_seconds
    this%num_soil_levels      = num_soil_levels
    this%forcing_height       = forcing_height
    this%soil_level_thickness = soil_level_thickness
    this%soil_level_nodes     = soil_level_nodes
    
    if(simulation_end /= "") then
      call calc_sec_since(simulation_start,simulation_end,0,run_time)
      if(mod(int(run_time),timestep_seconds) /= 0) stop "calculated run time not divisible by timestep"
      this%run_timesteps = int(run_time)/timestep_seconds
    elseif(run_days /= 0 .or. run_hours /= 0 .or. run_minutes /= 0 .or. run_seconds /= 0) then
      run_time = 86400*run_days + 3600*run_hours + 60*run_minutes + run_seconds
      if(mod(int(run_time),timestep_seconds) /= 0) stop "calculated run time not divisible by timestep"
      this%run_timesteps = int(run_time)/timestep_seconds
    elseif(run_timesteps /= 0) then
      this%run_timesteps = run_timesteps
    else
      stop "no valid simulation length in namelist"
    end if
    
    this%initial_time = huge(1.d0)

    if(land_model == NOAHMP_LAND_SURFACE_MODEL) then
      this%dynamic_vegetation_option         = dynamic_vegetation_option
      this%canopy_stomatal_resistance_option = canopy_stomatal_resistance_option
      this%soil_wetness_option               = soil_wetness_option
      this%runoff_option                     = runoff_option
      this%surface_exchange_option           = surface_exchange_option
      this%supercooled_soilwater_option      = supercooled_soilwater_option
      this%frozen_soil_adjust_option         = frozen_soil_adjust_option
      this%radiative_transfer_option         = radiative_transfer_option
      this%snow_albedo_option                = snow_albedo_option
      this%precip_partition_option           = precip_partition_option
      this%soil_temp_lower_bdy_option        = soil_temp_lower_bdy_option
      this%soil_temp_time_scheme_option      = soil_temp_time_scheme_option
      this%surface_evap_resistance_option    = surface_evap_resistance_option
      this%glacier_option                    = glacier_option
    end if

  end subroutine ReadNamelist

end module NamelistRead
