util = require "util"

HUMAN_LABELS = " KMGTPE"
SPACE = "         "

humanize = (number, base = 1024.0) ->
  index = HUMAN_LABELS.indexOf(" ")
  number = Math.abs(number)
  originalNumber = number
  while number >= base and index < HUMAN_LABELS.length - 1
    number /= base
    index += 1
  if originalNumber > base
    number = if number < 10 then roundToPrecision(number, 2) else Math.round(number)
  label = HUMAN_LABELS[index]
  if label == " " then label = ""
  number = number.toString()[...4]
  # compensate for sloppy floating-point rounding:
  while number.indexOf(".") > 0 and number[number.length - 1] == "0"
    number = number[0 ... number.length - 1]
  lpad(number.toString()[...4] + label, 5)

roundToPrecision = (number, digits, op = "round") ->
  if number == 0 then return 0
  scale = digits - Math.floor(Math.log(number) / Math.log(10)) - 1
  Math[op](number * Math.pow(10, scale)) * Math.pow(10, -scale)

lpad = (s, n) ->
  if s.length >= n then s else lpad(SPACE[0 ... n - s.length] + s, n)


exports.humanize = humanize
exports.lpad = lpad
exports.roundToPrecision = roundToPrecision
