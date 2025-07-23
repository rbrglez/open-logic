<img src="../Logo.png" alt="Logo" width="400">

# olo_base_arb_wrr

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_arb_wrr.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_arb_wrr.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_arb_wrr.json?cacheSeconds=0)

VHDL Source: [olo_base_arb_wrr](../../src/base/vhdl/olo_base_arb_wrr.vhd)

## Description

This entity implements a weighted round-robin arbiter. Each input in the _In\_Req_ vector is assigned a configurable weight via the _In\_Weights_ vector. The weight specifies how many identical grants on the _Out\_Grant_ vector can be issued consecutively before the arbiter moves to the next grant.

**Waveform with No Latency (Latency_g = 0):**

![NoLatency](./arb/olo_base_arb_wrr_no_latency.png)

**Waveform with Latency (Latency_g = 1):**

![Latency](./arb/olo_base_arb_wrr_latency.png)

## Generics

| Name          | Type     | Default | Description                                                  |
| :------------ | :------- | ------- | :----------------------------------------------------------- |
| GrantWidth_g  | positive | -       | Number of requesters (number of bits in _In\_Req_ and _Out\_Grant_ vectors) |
| WeightWidth_g | positive | -       | Number of bits in single weight |
| Latency_g     | natural  | -       | Allowed values:<br> **0** - for combinatorial operation,<br> **1** - for registered (pipelined) operation |


## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_) |

### Request Interface

| Name       | In/Out | Length                         | Default | Description                                                  |
| :--------- | :----- | :----------------------------- | ------- | :----------------------------------------------------------- |
| In_Valid   | in     | 1                              | -       | AXI4-Stream handshaking signal for _In\_Weights_ and _In\_Req_ |
| In_Ready   | out    | 1                              | N/A     | AXI4-Stream handshaking signal for _In\_Weights_ and _In\_Req_ |
| In_Weights | in     | _GrantWidth\_g*WeightWidth\_g_ | -       | Weights for each requestor |
| In_Req     | in     | _GrantWidth\_g_                | -       | Request vector. The highest (left-most) bit has highest priority |

### Grant Interface

| Name      | In/Out | Length          | Default | Description                                                  |
| :-------- | :----- | :-------------- | ------- | :----------------------------------------------------------- |
| Out_Valid | out    | 1               | N/A     | AXI4-Stream handshaking signal for _Out\_Grant_ |
| Out_Grant | out    | _GrantWidth\_g_ | N/A     | Grant output signal |

## Architecture

Not described in detail. Refer to the code for details.
