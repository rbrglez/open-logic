<img src="../Logo.png" alt="Logo" width="400">

# olo_axi_byte_stream_bridge

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_axi_byte_stream_bridge.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_axi_byte_stream_bridge.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_axi_byte_stream_bridge.json?cacheSeconds=0)

VHDL Source: [olo_axi_byte_stream_bridge](../../src/intf/vhdl/olo_axi_byte_stream_bridge.vhd)

## Description

### Overview

## Interfaces

### Control

| Name | In/Out | Length | Default | Description                                     |
| :--- | :----- | :----- | ------- | :---------------------------------------------- |
| Clk  | in     | 1      | -       | Clock                                           |
| Rst  | in     | 1      | -       | Reset input (high-active, synchronous to _Clk_) |

### In Request Byte Stream Interface

| Name            | In/Out | Length          | Default | Description                               |
| :-------------- | :----- | :-------------- | ------- | :---------------------------------------- |
| In_ReqReady     | out    | 1               | N/A     | AXI-S handshaking signal for _In_ReqData_ |
| In_ReqValid     | in     | 1               | '1'     | AXI-S handshaking signal for _In_ReqData_ |
| In_ReqData      | in     | 8               | -       | Input Byte Stream __REQUEST__ Data        |

### Out Response Byte Stream Interface

| Name            | In/Out | Length          | Default | Description                                |
| :-------------- | :----- | :-------------- | ------- | :----------------------------------------- |
| In_RespReady    | in     | 1               | '1'     | AXI-S handshaking signal for _In_RespData_ |
| In_RespValid    | out    | 1               | N/A     | AXI-S handshaking signal for _In_RespData_ |
| In_RespData     | out    | 8               | N/A     | Input Byte Stream __RESPONSE__ Data        |

### Master AXI-Lite Interface

| Name          | In/Out | Length | Default | Description                                                  |
| :------------ | :----- | :----- | ------- | :----------------------------------------------------------- |
| M_AxiLite_... | *      | *      | *       | AXI4-Lite master interface. For the exact meaning of the signals, refer to the AXI4-Lite protocol specification. |

## Architecture
