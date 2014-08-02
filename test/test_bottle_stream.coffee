helpers = require "./helpers"
mocha_sprinkles = require "mocha-sprinkles"
Q = require "q"
stream = require "stream"
should = require "should"
util = require "util"

bottle_stream = require "../lib/4q/bottle_stream"
metadata = require "../lib/4q/metadata"

bufferSink = helpers.bufferSink
bufferSource = helpers.bufferSource
fromHex = helpers.fromHex
future = mocha_sprinkles.future
toHex = helpers.toHex


describe "Writable4QStream", ->
  it "writes magic", future ->
    sink = bufferSink()
    b = new bottle_stream.Writable4QStream(sink)
    b.writeMagic().then ->
      sink.getBuffer().should.eql bottle_stream.MAGIC

  it "writes a bottle header", future ->
    sink = bufferSink()
    b = new bottle_stream.Writable4QStream(sink)
    metadata = new metadata.Metadata()
    metadata.addNumber(0, 150)
    b.writeBottleHeader(10, metadata).then ->
      toHex(sink.getBuffer()).should.eql "a00480029601"

  it "writes data", future ->
    data = bufferSource(fromHex("ff00ff00"))
    sink = bufferSink()
    b = new bottle_stream.Writable4QStream(sink)
    b.writeData(4, data).then ->
      toHex(sink.getBuffer()).should.eql "04ff00ff00"

  it "streams data", future ->
    # just to verify that the data is written as it comes in, and the event isn't triggered until completion.
    data = fromHex("ff00")
    slowStream = new stream.Readable()
    slowStream._read = (n) ->
    slowStream.push data
    sink = bufferSink()
    b = new bottle_stream.Writable4QStream(sink)
    b.writeData(4, slowStream).then ->
      toHex(sink.getBuffer()).should.eql "04ff00ff00"
    Q.delay(100).then ->
      slowStream.push data
      Q.delay(100).then ->
        slowStream.push null
