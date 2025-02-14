# Esta función puede evaluar solo una medida de inflación
"""
    evalsim(data_eval::CountryStructure, config::SimConfig; 
        rndseed = DEFAULT_SEED, 
        short = false) -> (metrics, tray_infl)

Esta función genera la trayectoria paramétrica , las trayectorias de simulación
y las métricas de evaluación utilizando la configuración [`SimConfig`](@ref). 

Las métricas de evaluación se devuelven en el diccionario `metrics`. Si
`short=true`, el diccionario contiene únicamente la llave `:mse`. Este
diccionario corto es útil para optimización iterativa. Por defecto, se computa
el diccionario completo de métricas, pero este proceso es más intensivo en
memoria. Ver también [`eval_metrics`](@ref).

Las trayectorias de inflación simuladas son devueltas en `tray_infl` como un
arreglo tridimensional de dimensión `(T, 1, K)`, en donde `T` corresponde a los
períodos de inflación computados y `K` representa el número de realizaciones de
la simulación. La dimensión unitaria `1` sirve para concatenar posteriormente
los resultados de simulación. Por ejemplo, en el cómputo de una medida de
promedio ponderado óptima. 

## Utilización

La función `evalsim` recibe un `CountryStructure` y un `AbstractConfig` del tipo
`SimConfig`.

### Ejemplo

Teniendo una configuración del tipo `SimConfig` y un set de datos `gtdata_eval`

```julia-repl 
julia> config = SimConfig(
    InflationPercentileEq(69), 
    ResampleScrambleVarMonths(), 
    TrendRandomWalk(), 
    InflationTotalRebaseCPI(36, 2), 10_000)
SimConfig{InflationPercentileEq, ResampleScrambleVarMonths, TrendRandomWalk{Float32}}
|─> Función de inflación            : Percentil equiponderado 69.0
|─> Función de remuestreo           : Bootstrap IID por meses de ocurrencia
|─> Función de tendencia            : Tendencia de caminata aleatoria
|─> Método de inflación paramétrica : Variación interanual IPC con cambios de base sintéticos (36, 2)
|─> Número de simulaciones          : 10000

julia> results, tray_infl = evalsim(gtdata_eval, config);
┌ Info: Evaluación de medida de inflación
│   medida = "Percentil equiponderado 69.0"
│   remuestreo = "Bootstrap IID por meses de ocurrencia"
│   tendencia = "Tendencia de caminata aleatoria"
│   evaluación = "Variación interanual IPC con cambios de base sintéticos (36, 2)"
└   simulaciones = 10000

┌ Info: Métricas de evaluación:
│   mse_std_error = 0.0011911743134260177
│   mse_bias = 0.62594384f0
│   mse_var = 0.23529443f0
│   huber = 0.425227918501327
│   std_mse_dist = 0.11911743f0
│   mse_cov = 0.16402239f0
│   mae = 0.8003128f0
│   me = -0.7897533f0
│   rmse = 1.0108289f0
│   T = 217
│   mse = 1.0252613f0
│   corr = 0.98361874f0
└   std_sqerr_dist = 1.4591569f0
```
"""
function evalsim(data::CountryStructure, config::SimConfig; 
    rndseed = DEFAULT_SEED, 
    short = false)
  
    # Obtener datos hasta la fecha de configuración 
    data_eval = data[config.traindate]

    # Obtener la trayectoria paramétrica de inflación 
    param = InflationParameter(config.paramfn, config.resamplefn, config.trendfn)
    tray_infl_pob = param(data_eval)

    @info "Evaluación de medida de inflación" medida=measure_name(config.inflfn) remuestreo=method_name(config.resamplefn) tendencia=method_name(config.trendfn) evaluación=measure_name(config.paramfn) simulaciones=config.nsim traindate=config.traindate

    # Generar las trayectorias de inflación de simulación 
    tray_infl = pargentrayinfl(config.inflfn, # función de inflación
        config.resamplefn, # función de remuestreo
        config.trendfn, # función de tendencia
        data_eval, # datos de evaluación 
        rndseed = rndseed, K=config.nsim)
    println()

    # Métricas de evaluación 
    metrics = eval_metrics(tray_infl, tray_infl_pob; short)
    @info "Métricas de evaluación:" metrics...

    # Devolver estos valores
    metrics, tray_infl
end

# Función para obtener diccionario de resultados y trayectorias a partir de un
# AbstractConfig
"""
    makesim(data, config::AbstractConfig; 
        rndseed = DEFAULT_SEED
        short = false) -> (metrics, tray_infl)

## Utilización
Esta función utiliza la función `evalsim` para generar un set de simulaciones en
base a un `CountryStructure` y un `AbstractConfig`, y genera un diccionario
`results` con todas las métricas de evaluación y con la información del
`AbstractConfig` utilizado para generarlas. Adicionalmente genera un objeto con
las trayectorias de inflación.

### Ejemplos
`makesim` recibe un `CountryStructure` y un `AbstractConfig`, para trasladarlo a
`evalsim` y generar las simulaciones. Almacena las métricas y los parámetros de
simulación en el diccionario results, y Adicionalmente devuelve las trayectoria
de simulacion.

```julia-repl 
julia> results, tray_infl = makesim(gtdata_eval, configA);
┌ Info: Evaluación de medida de inflación
│   medida = "Variación interanual IPC"
│   remuestreo = "Block bootstrap estacionario con bloque esperado 36"
│   tendencia = "Tendencia de caminata aleatoria"
└   simulaciones = 1000

┌ Info: Métricas de evaluación:
│   mse = 7.518966f0
│   std_sim_error = 0.48772313050091165
│   rmse = 1.9927315f0
│   me = 0.42103088f0
└   mae = 1.9927315f0
```

Exploramos el diccionario `results`:

```julia-repl 
julia> results
Dict{Symbol, Any} with 11 entries:
  :trendfn       => TrendRandomWalk{Float32}(Float32[0.953769, 0.948405, 0.926209, 0.902285, 0.832036, 0.825772, 0.799508, 0.789099, 0.764708, 0.757526  …  1.04656, 1.0…  :params        => (nothing,)
  :measure       => "Variación interanual IPC"
  :resamplefn    => ResampleSBB(36, Distributions.Geometric{Float64}(p=0.0277778))
  :me            => 0.421031
  :mae           => 1.99273
  :nsim          => 1000
  :rmse          => 1.99273
  :inflfn        => InflationTotalCPI()
  :mse           => 7.51897
  :std_sim_error => 0.487723
```
"""
function makesim(data, config::AbstractConfig; 
    rndseed = DEFAULT_SEED, 
    short = false)
        
     # Ejecutar la simulación y obtener los resultados 
    metrics, tray_infl = evalsim(data, config; rndseed, short)

    # Agregar resultados a diccionario 
    results = struct2dict(config)
    for (key, value) in metrics
        results[key] = value
    end
    results[:measure] = CPIDataBase.measure_name(config.inflfn)
    results[:params] = CPIDataBase.params(config.inflfn)

    return results, tray_infl 
end


# Función para ejecutar lote de simulaciones 
"""
    run_batch(data, dict_list_params, savepath; 
        savetrajectories = true, 
        rndseed = DEFAULT_SEED)

La función `run_batch` genera paquetes de simulaciones con base en el
diccionario de parámetros de configuración.

## Utilización 
La función recibe un `CountryStructure`, un diccionario con vectores que
contienen parámetros de simulación y un directorio para almacenar archivos con
las métricas de cada una de las evaluaciones generadas.

### Ejemplo
Generamos un diccionario con parámetros de configuración para percentiles
equiponderados, desde el percentil 60 hasta el percentil 80. Esto genera un
diccionario con 21 configuraciones distintas para evaluación.

```julia-repl 
dict_prueba = Dict(
    :inflfn => InflationPercentileWeighted.(50:80), 
    :resamplefn => resamplefn, 
    :trendfn => trendfn,
    :paramfn => paramfn, 
    :nsim => 1000) |> dict_list`
``` 
Una vez creado `dict_prueba`, podemos generar el paquete de simulación utilizando
`run_batch`.
```julia-repl 
julia> run_batch(gtdata_eval, dict_prueba, savepath)
...
```

Una vez generadas todas las simulaciones podemos obtener los datos mediante la
función `collect_results`. Esta función lee los resultados desde `savepath` y
los presenta en un `DataFrame`.

```julia-repl 
julia> df = collect_results(savepath); 
[ Info: Scanning folder `savepath` for result files.
[ Info: Added 31 entries.

julia> select(df, :measure, :mse)
31×2 DataFrame
 Row │ measure                   mse       
     │ String?                   Float32?  
─────┼─────────────────────────────────────
   1 │ Percentil ponderado 50.0  17.9208
   2 │ Percentil ponderado 51.0  16.8813
   3 │ Percentil ponderado 52.0  15.874
   4 │ Percentil ponderado 53.0  14.876
  ⋮  │            ⋮                  ⋮
  28 │ Percentil ponderado 77.0   2.85501
  29 │ Percentil ponderado 78.0   4.32532
  30 │ Percentil ponderado 79.0   6.33717
  31 │ Percentil ponderado 80.0   9.02473
                            23 rows omitted
```
"""
function run_batch(data, dict_list_params, savepath; 
    savetrajectories = true, 
    rndseed = DEFAULT_SEED)

    # Ejecutar lote de simulaciones 
    for (i, dict_params) in enumerate(dict_list_params)
        @info "Ejecutando simulación $i de $(length(dict_list_params))..."
        config = dict_config(dict_params)
        results, tray_infl = makesim(data, config;
            rndseed = rndseed)
        print("\n\n\n") 
        
        # Guardar los resultados 
        filename = savename(config, "jld2")
        
        # Resultados de evaluación para collect_results 
        wsave(joinpath(savepath, filename), tostringdict(results))
        
        # Guardar trayectorias de inflación, directorio tray_infl de la ruta de guardado
        savetrajectories && wsave(joinpath(savepath, "tray_infl", filename), "tray_infl", tray_infl)
    end

end


# Funciones de ayuda 

"""
    dict_config(params::Dict)

Función para convertir diccionario de parámetros a `SimConfig` o `CrossEvalConfig`.
"""
function dict_config(params::Dict)
    # CrossEvalConfig contiene el campo de períodos de evaluación 
    if !(:eval_size in keys(params))
        config = SimConfig(params[:inflfn], params[:resamplefn], params[:trendfn], params[:paramfn], params[:nsim], params[:traindate])
    else
        config = CrossEvalConfig(params[:inflfn], params[:resamplefn], params[:trendfn], params[:paramfn], params[:nsim], params[:traindate], params[:eval_size])        
    end
    config 
end

# Método opcional para lista de configuraciones
dict_config(params::AbstractVector) = dict_config.(params)