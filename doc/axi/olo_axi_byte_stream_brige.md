<img src="../Logo.png" alt="Logo" width="400">

# olo_axi_byte_stream_bridge

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_axi_byte_stream_bridge.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_axi_byte_stream_bridge.json?cacheSeconds=0)
![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_axi_byte_stream_bridge.json?cacheSeconds=0)

VHDL Source: [olo_axi_byte_stream_bridge](../../src/intf/vhdl/olo_axi_byte_stream_bridge.vhd)

## Description

This component implements the _Open Logic Byte Stream Protocol_ and acts as a
bridge between a byte stream request/response interfaces and an AXI4-Lite
master interface.

It receives a Request Byte Stream through the _In Request Byte Stream
Interface_. The incoming byte stream is decoded to determine the requested
operation. Based on the decoded request, the component performs the
corresponding read or write transaction on the AXI4-Lite master interface.

Once the AXI4-Lite transaction completes, the component generates a Response
Byte Stream containing the operation result and transmits it via the _Out
Response Byte Stream Interface_.

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

## Open Logic Byte Stream Protocol

The Open Logic Byte Stream Protocol is designed to operate over any
byte-oriented transport medium, such as __SPI__, __I2C__, __UART__, or similar
interfaces. The protocol is transport-agnostic.

The protocol defines Request and Response frames, each identified by a
distinct synchronization sequence.

Every frame is protected by a CRC to detect transmission errors. If a CRC error
is detected, the affected Request frame is discarded and the receiver resumes
listening for the next valid Request frame.

### Request Frame Format

__byte[1:0] - Synchronization Bytes__

- Request Synchronization Bytes: __0x7A5A__

These two synchronization bytes indicate the potential start of a frame and are
used to re-establish frame alignment if it is lost due to transmission errors.

A two-byte synchronization pattern is used to reduce the probability of false
detection to 1/65,536, compared to 1/256 for a single-byte pattern. This
significantly improves resynchronization robustness after bit errors.

__byte[2] - Command Byte__

| Bits       | Description                                               |
| :--------- | --------------------------------------------------------- |
| [7]        | __Type__: <br /> '1' = Read, <br /> '0' = Write           |
| [5:4]      | __Address Bytes__ encoded as `2^N` <br /> "00" = 1 Byte <br /> "01" = 2 Bytes <br /> "10" = 4 Bytes <br /> "11" = 8 Bytes |
| [1:0]      | __Data Bytes__ encoded as `2^N` <br /> "00" = 1 Byte <br /> "01" = 2 Bytes <br /> "10" = 4 Bytes <br /> "11" = 8 Bytes |
| [6], [3:2] | Reserved for future use                                   |

Reserved bits may be used in future revisions to extend data length encoding or to support AXI4 burst transactions.

__byte[3] - Transaction ID__

A monotonically increasing transaction ID assigned by the requester.

The ID is echoed in the response and allows the requester to match responses to
requests, enabling detection of lost or out-of-order frames.

__byte[4:N-1] - Address and Data Bytes__

- __Read request__:  Contains address bytes only
- __Write request__: Contains address bytes followed by data bytes

The number of address and data bytes is determined by the command byte.

__byte[N:N+1] - CRC__

A 16-bit CRC appended at the end of the frame to verify frame integrity.

The CRC is calculated over the entire frame excluding the synchronization
bytes

Frames with an invalid CRC are dropped.

If bit errors corrupt the header, frame alignment may be lost. In this case,
the receiver searches for the next valid synchronization sequence. If a sync
sequence is detected within a corrupted frame, the CRC check will fail, and
resynchronization continues.

### Response Frame Format


__byte[1:0] - Synchronization Bytes__

- Request Synchronization Bytes: __0x7B5B__

A different synchronization pattern from the request frame is used to clearly
distinguish responses from requests during debugging and protocol analysis.

__byte[2] - Status Byte__

| Bits       | Description                                                                     |
| :--------- | ------------------------------------------------------------------------------- |
| [7]        | __Type__: <br /> '1' = Read, <br /> '0' = Write                                 |
| [5:4]      | __AXI Response code__ <br /> "00" - OKAY, <br /> "01" - EXOKAY, <br /> "10" - SLVERR, <br /> "11" - DECERR |
| [1:0]      | __Data Bytes__ encoded as `2^N` <br /> "00" = 1 Byte <br /> "01" = 2 Bytes <br /> "10" = 4 Bytes <br /> "11" = 8 Bytes |
| [6], [3:2] | Reserved for future use                                                         |

__byte[3] - Transaction ID__

The ID of the corresponding request frame.

__byte[4:N-1] - Data Bytes__

- __Read response__ : Contains data bytes returned from the AXI-Lite read
- __Write response__: These Bytes are not present


__byte[N:N+1] - CRC__

A 16-bit CRC appended at the end of the frame.

The CRC is calculated over the entire frame excluding the synchronization bytes

## Architecture