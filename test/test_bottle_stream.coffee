mocha_sprinkles = require "mocha-sprinkles"
Q = require "q"
stream = require "stream"
should = require "should"
toolkit = require "stream-toolkit"
util = require "util"

bottle_header = require "../lib/4q/lib4q/bottle_header"
bottle_stream = require "../lib/4q/lib4q/bottle_stream"

future = mocha_sprinkles.future

MAGIC_STRING = "f09f8dbc0000"

shouldQThrow = (promise, message) ->
  promise.then((-> throw new Error("Expected exception, got valid promise")), ((err) -> (-> throw err).should.throw message))

describe "WritableBottle", ->
  it "writes a bottle header", future ->
    m = new bottle_header.Header()
    m.addNumber(0, 150)
    sink = new toolkit.SinkStream()
    b = new bottle_stream.WritableBottle(10, m)
    b.close()
    b.pipe(sink).then ->
      toolkit.toHex(sink.getBuffer()).should.eql "#{MAGIC_STRING}a00380019600"

  it "writes data", future ->
    data = new toolkit.SourceStream(toolkit.fromHex("ff00ff00"))
    sink = new toolkit.SinkStream()
    b = new bottle_stream.WritableBottle(10, new bottle_header.Header())
    b.pipe(sink)
    b.writeData(data, 4).then ->
      toolkit.toHex(sink.getBuffer()).should.eql "#{MAGIC_STRING}a0000104ff00ff00"

  it "writes nested bottle data", future ->
    sink = new toolkit.SinkStream()
    b = new bottle_stream.WritableBottle(10, new bottle_header.Header())
    b.pipe(sink)
    b2 = new bottle_stream.WritableBottle(14, new bottle_header.Header())
    promise = b.writeData(b2)
    b2.close()
    promise.then ->
      toolkit.toHex(sink.getBuffer()).should.eql "#{MAGIC_STRING}a00080#{MAGIC_STRING}e00000"

  it "streams data", future ->
    # just to verify that the data is written as it comes in, and the event isn't triggered until completion.
    data = toolkit.fromHex("ff00")
    slowStream = new stream.Readable()
    slowStream._read = (n) ->
    slowStream.push data
    sink = new toolkit.SinkStream()
    b = new bottle_stream.WritableBottle(10, new bottle_header.Header())
    b.pipe(sink)
    b.writeData(slowStream, 4).then ->
      toolkit.toHex(sink.getBuffer()).should.eql "#{MAGIC_STRING}e0006004ff00ff00"
    Q.delay(100).then ->
      slowStream.push data
      Q.delay(100).then ->
        slowStream.push null

  it "writes several datas", future ->
    data1 = new toolkit.SourceStream(toolkit.fromHex("f0f0f0"))
    data2 = new toolkit.SourceStream(toolkit.fromHex("e0e0e0"))
    data3 = new toolkit.SourceStream(toolkit.fromHex("cccccc"))
    sink = new toolkit.SinkStream()
    b = new bottle_stream.WritableBottle(14, new bottle_header.Header())
    b.pipe(sink)
    b.writeData(data1, 3).then ->
      b.writeData(data2, 3)
    .then ->
      b.writeData(data3, 3)
    .then ->
      b.close()
    .then ->
      toolkit.toHex(sink.getBuffer()).should.eql "#{MAGIC_STRING}e0000103f0f0f00103e0e0e00103cccccc00"


describe "ReadableBottle", ->
  BASIC_MAGIC = "f09f8dbc00000000"

  it "validates the header", future ->
    b = new bottle_stream.ReadableBottle(new toolkit.SourceStream(toolkit.fromHex("00")))
    shouldQThrow b.getHeader(), /magic/
    b = new bottle_stream.ReadableBottle(new toolkit.SourceStream(toolkit.fromHex("f09f8dbcff000000")))
    shouldQThrow b.getHeader(), /version/
    b = new bottle_stream.ReadableBottle(new toolkit.SourceStream(toolkit.fromHex("f09f8dbc00ff0000")))
    shouldQThrow b.getHeader(), /flags/

  it "reads the header", future ->
    b = new bottle_stream.ReadableBottle(new toolkit.SourceStream(toolkit.fromHex("f09f8dbc00002000")))
    b.getHeader().then (header) ->
      header.fields.length.should.eql 0
      b.getType().then (t) ->
        t.should.eql 2
    b = new bottle_stream.ReadableBottle(new toolkit.SourceStream(toolkit.fromHex("f09f8dbc0000e003800196")))
    b.getHeader().then (header) ->
      header.fields.length.should.eql 1
      header.fields[0].number.should.eql 150
      b.getType().then (t) ->
        t.should.eql 14

  it "reads a data block", future ->
    b = new bottle_stream.ReadableBottle(new toolkit.SourceStream(toolkit.fromHex("#{BASIC_MAGIC}010568656c6c6f00")))
    toolkit.qread(b).then (data) ->
      sink = new toolkit.SinkStream()
      toolkit.qpipe(data, sink).then ->
        sink.getBuffer().toString().should.eql "hello"
        toolkit.qread(b).then (data) ->
          (data?).should.eql false

  it "reads a continuing data block", future ->
    b = new bottle_stream.ReadableBottle(new toolkit.SourceStream(toolkit.fromHex("#{BASIC_MAGIC}4102686541016c01026c6f00")))
    toolkit.qread(b).then (data) ->
      sink = new toolkit.SinkStream()
      toolkit.qpipe(data, sink).then ->
        sink.getBuffer().toString().should.eql "hello"
        toolkit.qread(b).then (data) ->
          (data?).should.eql false

  it "reads several datas", future ->
    b = new bottle_stream.ReadableBottle(new toolkit.SourceStream(toolkit.fromHex("#{BASIC_MAGIC}0103f0f0f00103e0e0e00103cccccc00")))
    toolkit.qread(b).then (data) ->
      sink = new toolkit.SinkStream()
      toolkit.qpipe(data, sink).then ->
        toolkit.toHex(sink.getBuffer()).should.eql "f0f0f0"
        toolkit.qread(b)
    .then (data) ->
      sink = new toolkit.SinkStream()
      toolkit.qpipe(data, sink).then ->
        toolkit.toHex(sink.getBuffer()).should.eql "e0e0e0"
        toolkit.qread(b)
    .then (data) ->
      sink = new toolkit.SinkStream()
      toolkit.qpipe(data, sink).then ->
        toolkit.toHex(sink.getBuffer()).should.eql "cccccc"
        toolkit.qread(b)
    .then (data) ->
      (data?).should.eql false

  it "reads several bottles from the same stream", future ->
    source = new toolkit.SourceStream(toolkit.fromHex("#{BASIC_MAGIC}010363617400#{BASIC_MAGIC}010368617400"))
    b = new bottle_stream.ReadableBottle(source)
    toolkit.qread(b).then (data) ->
      sink = new toolkit.SinkStream()
      toolkit.qpipe(data, sink).then ->
        sink.getBuffer().toString().should.eql "cat"
        toolkit.qread(b)
    .then (data) ->
      (data?).should.eql false
      b = new bottle_stream.ReadableBottle(source)
      toolkit.qread(b)
    .then (data) ->
      sink = new toolkit.SinkStream()
      toolkit.qpipe(data, sink).then ->
        sink.getBuffer().toString().should.eql "hat"
        toolkit.qread(b)
    .then (data) ->
      (data?).should.eql false
