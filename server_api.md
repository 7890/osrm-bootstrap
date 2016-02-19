# Server API

(This is a copy of https://github.com/Project-OSRM/osrm-backend/wiki/Server-api)

The HTTP interface provided by `osrm-routed` (partially) implements _HTTP 1.1_ and serves queries much like normal web servers do.

The general structure of all queries looks like this:

```
http://{server address}/{service}?{parameter}={value}
```
Example:

```
http://127.0.0.1:5000/nearest?loc=52.4224,13.333086
```

The response is returned as JSON object by default. If you call from within Javascript and want to specify a callback function that should be called use the `jsonp={callback name}` parameter.

Each response has the following general structure:

```JSON
{
  "status": 200,
  "status_message": "Message text",
  .....
}
```

* `status` the status code. 200 means successful, 207 means no route was found.
* `status_message` (optional) can either be `Found route between points` or `Cannot find route between points`

## Available Services

Each service is implemented as a plugin for OSRM. Currently the following services are available:

| Service     |           Description                                     |
|-------------|-----------------------------------------------------------|
| `viaroute`  | shortest path between given coordinates                   |
| `nearest`   | returns the nearest street segment for a given coordinate |
| `table`     | computes distance tables for given coordinates            |
| `match`     | matches given coordinates to the road network             |
| `trip`      | Compute the shortest round trip between given coordinates |


## Service `nearest`

### Query

```
http://{server}/nearest?loc={lat,lon}
```

|Parameter|Description|
|---------|-----------|
|loc|Location of the node as latitude longitude pair separated by a comma|

### Response

* `name` Name of the street the coordinate snapped to
* `mapped_coordinate` Array that contains the `[lat, lon]` pair of the snapped coordinate

### Example

Query
```
http://router.project-osrm.org/nearest?loc=52.4224,13.333086
```

Response:
```JSON
{
    "status": 200,
    "mapped_coordinate": [
        52.42259,
        13.33383
    ],
    "name": "Mariannenstraße"
}
```

## Service `viaroute`

This service provides shortest path queries with multiple via locations. It supports the computation of alternative paths as well as giving turn instructions.

### Query

```
http://{server}/viaroute?loc={lat,lon}&loc={lat,lon}<&loc={lat,lon} ...>
```

|Parameter   |Values                    |Description                                                            |
|------------|--------------------------|-----------------------------------------------------------------------|
|loc         |lat,lon                   |Location of the via point                                              |
|locs        |Encoded polyline          |Location of the via point encoded as [polyline](https://www.npmjs.com/package/polyline) |
|z           | `0 ... 18` (default)     |Zoom level used for compressing the route geometry accordingly         |
|output      |`json` (default), `gpx`   |Format of the response                                                 |
|instructions|`true`, `false` (default) |Return route instructions for each route                               |
|alt         |`true` (default), `false` |Return an alternative route                                            |
|geometry    |`true` (default), `false` |Return route geometry                                                  |
|compression |`true` (default), `false` |Compress route geometry as a polyline; geometry is a list of [lat, lng] pairs if `false` |
|uturns      |`false` (default), `true` |Enable u-turns at all via points                                       |
|u           |`false` (default), `true` |Specify after each `loc`. Enables/disables u-turn at the via.          |
|hint        | Base64 `string`          |Derives the location of coordinate in the street network, one per `loc`|
|checksum    |`integer`                 |Checksum of the `hint` parameters.                                     |

### Response

* `route_geometry` Geometry of the route compressed as [polyline](http://code.google.com/apis/maps/documentation/utilities/polylinealgorithm.html), but with 6 decimals. You can use the `npm` module [polyline](https://www.npmjs.com/package/polyline) to decompress it.
* `route_instructions` Array containing the instructions for each route segment. Each entry is an array of the following form:
  `[{drive instruction code}, {street name}, {length}, {location index}, {time}, {formated length}, {post-turn direction}, {post-turn azimuth}, {mode}, {pre-turn direction}, {pre-turn azimuth}]`
  * `driving directions code` integer or string in format `11-{exit_number}` (where `exit_number` is an integer) as defined in the source file [turn\_instructions.hpp](https://github.com/Project-OSRM/osrm-backend/blob/master/data_structures/turn_instructions.hpp).
  * `street name` name of the street as `string`
  * `length` length of the street in meters as `integer`
  * `position` index to the list of coordinates represented by the decoded `route_geometry` as `integer`
  * `time` travel time in seconds as `float`
  * `formated length` length with unit as `string`
  * `post-turn direction` abbreviation N: north, S: south, E: east, W: west, NW: North West, ... as `string`
  * `post-turn azimuth` as `float`
  * `mode` of transportation as defined in the profile as integer (usually 1 means the default mode, e.g. 'car' for the car profile, 'bike' for the bicycle profile etc.)
  * `pre-turn direction` abbreviation N: north, S: south, E: east, W: west, NW: North West, ... as `string`  (**new in 4.9.0**)
  * `pre-turn azimuth` as `float` (**new in 4.9.0**)
* `route_summary`
  * `total_distance` total length in meters as `integer`
  * `total_time` total trip time in seconds as `integer`
  * `start_point` name of the first street as `string`
  * `end_point` name of the last street as `string`
* `route_name` name of the route ("most prominent streets") as array of `string`
* `via_indices` index to the list of coordinates represented by the decoded `route_geometry` as `integer`
* `via_points` array of via points, each via point is an array of coordinates: `[lat, lon]`
* `hint_data` this can be used to speed up incremental queries, where only a few via change
  * `checksum` to be passed with the next requests
  * `locations` array of hints for each vis point append with use the `hint` parameter to pass it after the corresponding `loc`
* `found_alternative` `true` or `false`

If alternatives are requested (`alt=true`), following arrays may contain elements, one for each alternate route:

* `alternative_geometries` array of `route_geometry`
* `alternative_instructions` array of `route_instructions`
* `alternative_summaries` array of `route_summary`
* `alternative_names` array of `route_name`

### Example

Query
```
http://router.project-osrm.org/viaroute?loc=52.503033,13.420526&loc=52.516582,13.429290&instructions=true
```

Response:

```JSON
{
    "alternative_geometries": [
        "q~occB{}brX}KaHyY{QaW}OoN{IoHuEcIcFeM}HoKyGuBsA}U}OcvA}}@yxBgwAgT`kAyAjH_CvLyDvS{Mhv@aDbS{E`VkY{QofAur@eTkN{QsLkFcF_b@q\\_IqImKkJwNyMaGqFwD{KeEkGad@aq@eReTyPgOk_A_z@fE_q@^_GnIqkAkTeGcg@oMgCq@"
    ],
    "alternative_indices": [
        0,
        42
    ],
    "alternative_instructions": [
        [
            [
                "10",
                "Adalbertstra\u00dfe",
                701,
                0,
                71,
                "701m",
                "NE",
                23,
                1
            ],
            [
                "7",
                "L 1066",
                260,
                12,
                21,
                "260m",
                "NW",
                295,
                1
            ],
            [
                "3",
                "Michaelkirchstra\u00dfe",
                283,
                19,
                20,
                "283m",
                "NE",
                23,
                1
            ],
            [
                "1",
                "Michaelbr\u00fccke",
                70,
                24,
                5,
                "70m",
                "NE",
                27,
                1
            ],
            [
                "1",
                "An der Michaelbr\u00fccke",
                95,
                25,
                9,
                "95m",
                "NE",
                33,
                1
            ],
            [
                "2",
                "Lichtenberger Stra\u00dfe",
                326,
                29,
                23,
                "325m",
                "NE",
                54,
                1
            ],
            [
                "3",
                "Singerstra\u00dfe",
                149,
                35,
                15,
                "149m",
                "E",
                102,
                1
            ],
            [
                "7",
                "Krautstra\u00dfe",
                120,
                38,
                12,
                "120m",
                "N",
                13,
                1
            ],
            [
                "15",
                "",
                0,
                41,
                0,
                "0m",
                "N",
                0
            ]
        ]
    ],
    "alternative_names": [
        [
            "Adalbertstra\u00dfe",
            "Lichtenberger Stra\u00dfe"
        ]
    ],
    "alternative_summaries": [
        {
            "end_point": "Krautstra\u00dfe",
            "start_point": "Adalbertstra\u00dfe",
            "total_distance": 2005,
            "total_time": 169
        }
    ],
    "found_alternative": true,
    "hint_data": {
        "checksum": 2307491829,
        "locations": [
            "27oZAOC6GQCMVAAAEQAAAEIAAAAAAAAAAAAAAP____8AAAAA-SEhA-7HzAAAABEA",
            "TJm4A1Xa4QYIcgEABwAAAAgAAAA2AAAAAAAAADBB-QMAAAAA5lYhAyrqzAABABEA"
        ]
    },
    "route_geometry": "q~occB{}brX}KaHyY{QaW}OoN{IoHuEcIcFeM}HoKyGuBsAZ}Ip@aUXaZIqT_@sUi@kNgCk`@wAePsCwTwDuTsG}YwIsZgFuMmB_F_HmQ}NoVgFyGoCsDmK}KgLaJuHeEgEyCiHcFuEeDwFGmIKoQW{JwBwHeFmFmDePcNuJqIwBmBug@}c@yE}Dk]gYsPeImg@{MoJgCw`@sK_Ck@ot@qPkBg@_D{@cHgBeR}E{\\yIm_@}JuEeAiGaBuBi@eMcDuPkE{Djo@{@jMaCp_@eKt_BkTeGcg@oMgCq@",
    "route_instructions": [
        [
            "10",
            "Adalbertstra\u00dfe",
            251,
            0,
            26,
            "250m",
            "NE",
            23,
            1
        ],
        [
            "3",
            "Bethaniendamm",
            719,
            9,
            53,
            "719m",
            "E",
            99,
            1
        ],
        [
            "1",
            "Schillingbr\u00fccke",
            90,
            41,
            6,
            "90m",
            "NE",
            27,
            1
        ],
        [
            "1",
            "An der Schillingbr\u00fccke",
            108,
            43,
            12,
            "108m",
            "NE",
            28,
            1
        ],
        [
            "1",
            "Andreasstra\u00dfe",
            533,
            46,
            40,
            "532m",
            "N",
            13,
            1
        ],
        [
            "7",
            "Singerstra\u00dfe",
            212,
            62,
            22,
            "212m",
            "W",
            281,
            1
        ],
        [
            "3",
            "Krautstra\u00dfe",
            120,
            66,
            12,
            "120m",
            "N",
            13,
            1
        ],
        [
            "15",
            "",
            0,
            69,
            0,
            "0m",
            "N",
            0
        ]
    ],
    "route_name": [
        "Bethaniendamm",
        "Andreasstra\u00dfe"
    ],
    "route_summary": {
        "end_point": "Krautstra\u00dfe",
        "start_point": "Adalbertstra\u00dfe",
        "total_distance": 2034,
        "total_time": 164
    },
    "status": 200,
    "status_message": "Found route between points",
    "via_indices": [
        0,
        70
    ],
    "via_points": [
        [
            52.503033,
            13.420526
        ],
        [
            52.516582,
            13.42929
        ]
    ]
}
```

## Service `table`

This computes distance tables for the given via points. Please note that the distance in this case is the _travel time_ which is the default metric used by OSRM.
If only `loc` parameter is used, all pair-wise distances are computed.
If `dst` and `src` parameters are used instead, only pairs between scr/dst are computed.

### Query

```
http://{server}/table?loc={lat,lon}&loc={lat,lon}<&loc={lat,lon} ...>
```

|Parameter   |Values                    |Description                                                   |
|------------|--------------------------|--------------------------------------------------------------|
|loc         |lat,lon                   |Location of the via point for square matrix                   |
|src         |lat,lon                   |Location of the via point for rectangular matrix              |
|dst         |lat,lon                   |Location of the via point for rectangular matrix              |

### Response

* `distance_table` array of arrays that stores the matrix in row-major order. `distance_table[i][j]` gives the travel time from
  the i-th via to the j-th via point. Values are given in 10th of a second.
* `destination_coordinates` array of arrays that contains the `[lat, lon]` pair of the snapped coordinate
* `source_coordinates` array of arrays that contains the `[lat, lon]` pair of the snapped coordinate

### Example

With `loc`:
```
http://router.project-osrm.org/table?loc=52.554070,13.160621&loc=52.431272,13.720654&loc=52.554070,13.720654&loc=52.554070,13.160621
```

```JSON
{
    "distance_table": [
        [
            0,
            31089,
            31224,
            0
        ],
        [
            31248,
            0,
            13138,
            31248
        ],
        [
            31167,
            13188,
            0,
            31167
        ],
        [
            0,
            31089,
            31224,
            0
        ]
    ],
    "destination_coordinates": [
        [
            52.554070,
            13.160621
        ],
        [
            52.431272,
            13.720654
        ],
        [
            52.554070,
            13.720654
        ],
        [
            52.554070,
            13.160621
        ]
    ],
    "source_coordinates": [
        [
            52.554070,
            13.160621
        ],
        [
            52.431272,
            13.720654
        ],
        [
            52.554070,
            13.720654
        ],
        [
            52.554070,
            13.160621
        ]
    ]
}
```

With `src`/`dst`:
```
http://router.project-osrm.org/table?src=52.554070,13.160621&dst=52.431272,13.720654&dst=52.554070,13.720654&dst=52.554070,13.160621
```

```JSON
{
    "distance_table": [
        [
            31089,
            31224,
            0
        ]
    ],
    "destination_coordinates": [
        [
            52.431272,
            13.720654
        ],
        [
            52.554070,
            13.720654
        ],
        [
            52.554070,
            13.160621
        ]
    ],
    "source_coordinates": [
        [
            52.554070,
            13.160621
        ]
    ]
}
```

## Service `match`

Map matching matches given GPS points to the road network in the most plausible way. Currently the algorithm
works best with trace data that has a sample resolution of 5-10 samples/min.
Please note the request might result multiple sub-traces. Large jumps in the timestamps (>60s) or improbable transitions lead to trace splits if a complete matching could not be found.
The algorithm might not be able to match all points. Outliers are removed if they can not be matched successfully. The ```indices``` array contains the indices of the input location that could be matched.

### Query

```
http://{server}/match?loc={lat,lon}&t={timestamp}&loc={lat,lon}&t={timestamp}<&loc={lat,lon}&t={timestamp} ...>
```

|Parameter    |Values                   |Description                                                                              |
|-------------|-------------------------|-----------------------------------------------------------------------------------------|
|loc          |lat,lon                  |Location of the point                                                                    |
|locs         |Encoded polyline         |Location of the via point encoded as [polyline](https://www.npmjs.com/package/polyline)  |
|t            |UNIX-like timestamp      |Timestamp of the preceding point                                                         |
|geometry     |`true` (default), `false`|Return route geometry                                                                    |
|compression  |`true` (default), `false`|Compress route geometry as a polyline; geometry is a list of [lat, lng] pairs if `false` |
|classify     |`true`, `false` (default)|Return a confidence value for this matching                                              |
|instructions |`true`, `false` (default)|Return the instructions of the matched route, which each matched point as via.           |
|gps_precision|float value (default: 5) |Specify gps precision as standart deviation in meters. See [1]                           |
|matching_beta|float value (default: 10)|Specify beta value for matching algorithm. See [1]                                       |
|hint        |Encoded base64 string     |Derives the location of coordinate in the street network, one per `loc`                  |
|checksum    |Encoded base64 string     |Checksum of the `hint` parameters.                                                       |

### Response

* `matchings` array containing an object for each partial sub-matching of the trace.
  * `matched_points` coordinates of the points snapped to the road network in `[lat, lon]`
  * `indices` array that gives the indices of the matched coordinates in the original trace
  * `geometry` geometry of the matched trace in the road network. If `compression` is `true` (the default), the geometry is compressed as [polyline](http://code.google.com/apis/maps/documentation/utilities/polylinealgorithm.html), but with 6 decimals. You can use the `npm` module [polyline](https://www.npmjs.com/package/polyline) to decompress it
  * `confidence` value between 0 and 1, where 1 is very confident. Please note that the correctness of this value depends highly on the assumptions about the sample rate mentioned above.
  * `instructions` see `route_instructions` of the `viaroute` service.
  * `hint_data` input for the `hint` and `checksum` parameter. This can be used to enable umambigious coordinate snapping when passed to services like `viaroute` and `trip`.


### Example

```
http://router.project-osrm.org/match?loc=52.542648,13.393252&t=1424684612loc=52.543079,13.394780&t=1424684616&loc=52.542107,13.397389&t=1424684620&instructions=true
```

```JSON
{
    "matchings": [
        {
            "geometry": "}l}ecBksmpXmXmzAdAs@nwA{cAqPs`AkHka@",
            "hint_data": {
                "checksum": 4290023608,
                "locations": [
                    "wUcUAP____-tIAAAIgAAAHAAAAAAAAAAAAAAAP____8AAAAA37whA0ZdzAAAAAEB",
                    "NMoZAP____8-mQEABAAAALMAAAAAAAAAAAAAAP____8AAAAAU74hAxdjzAAAAAEB",
                    "_____0yfIQQMhgEAIQAAACkAAAAAAAAAAAAAAP____8AAAAAerohA6VtzAAAAAEB"
                ]
            },
            "indices": [
                0,
                1,
                2
            ],
            "instructions": [
                [
                    "10",
                    "Lortzingstra\u00dfe",
                    109,
                    0,
                    16,
                    "108m",
                    "NE",
                    65,
                    1
                ],
                [
                    "3",
                    "Putbusser Stra\u00dfe",
                    4,
                    1,
                    0,
                    "4m",
                    "SE",
                    156,
                    1
                ],
                [
                    "9",
                    "Putbusser Stra\u00dfe",
                    174,
                    2,
                    20,
                    "174m",
                    "SE",
                    155,
                    1
                ],
                [
                    "7",
                    "Demminer Stra\u00dfe",
                    118,
                    3,
                    12,
                    "118m",
                    "NE",
                    66,
                    1
                ],
                [
                    "15",
                    "",
                    0,
                    5,
                    0,
                    "0m",
                    "N",
                    0
                ]
            ],
            "matched_names": [
                "Lortzingstra\u00dfe",
                "Putbusser Stra\u00dfe",
                "Demminer Stra\u00dfe"
            ],
            "matched_points": [
                [
                    52.542686,
                    13.393222
                ],
                [
                    52.54306,
                    13.394711
                ],
                [
                    52.542072,
                    13.397413
                ]
            ]
        }
    ]
}

```

## Service `trip`

The trip plugin solves the famous Traveling Salesman Problem using a greedy heuristic (farest-insertion algorithm).
The returned path does not have to be the shortest path, as TSP is NP-hard it is only an approximation.
Note that if the input coordinates can not be joined by a single trip (e.g. the coordinates are on several disconnecte islands)
multiple trips for each connected component are returned.

### Query

```
http://{server}/trip?loc={lat,lon}&loc={lat,lon}<&loc={lat,lon} ...>
```

For all supported parameters see the `viaroute` plugin. `trip` does not support computing alternatives.

### Response

* `trips` array containing an object for each trip.
  * Object that models the reponse of `viaroute`. Additional members:
    * `permutation`: array of intergers. `permuation[i]` gives the position in the trip of the i-th input coordinate.

[1] "Hidden Markov Map Matching Through Noise and Sparseness"; P. Newson and J. Krumm; 2009; ACM.

# HTTP Pipelining

As noted at the top of this page, OSRM only partially implements _HTTP 1.1_. Notably absent is support for [_pipelining_](http://en.wikipedia.org/wiki/HTTP_pipelining), which allows multiple requests to be served over a single socket. [OSRM Issue #531](/Project-OSRM/osrm-backend/issues/531) has some documented workarounds.

# Public API usage policy

You are welcome to query our server for routes, if you adhere to the [API Usage Policy](API Usage Policy).
