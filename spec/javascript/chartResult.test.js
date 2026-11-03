import {test} from "node:test";
import assert from "node:assert/strict";
import {CHART_SLOTS, pieSlices, pivotSeries} from "../../app/javascript/wulin_agent/chartResult";

test("pivots series into one row per label", () => {
  const {rows, series, hiddenSeries} = pivotSeries([
    {label: "Q1", value: 1, series: "A"},
    {label: "Q1", value: 2, series: "B"},
    {label: "Q2", value: 3, series: "A"},
  ]);

  assert.deepEqual(rows, [{label: "Q1", A: 1, B: 2}, {label: "Q2", A: 3}]);
  assert.deepEqual(series, ["A", "B"]);
  assert.equal(hiddenSeries, 0);
});

test("treats points without a series as the single series 'value'", () => {
  const {rows, series} = pivotSeries([{label: "Red", value: 3}, {label: "Blue", value: 5}]);

  assert.deepEqual(series, ["value"]);
  assert.deepEqual(rows, [{label: "Red", value: 3}, {label: "Blue", value: 5}]);
});

test("draws no more series than the palette has colors, and counts the rest", () => {
  const data = Array.from({length: 8}, (_, i) => ({label: "Q1", value: i, series: `S${i + 1}`}));
  const {series, allSeries, hiddenSeries, rows} = pivotSeries(data);

  assert.equal(series.length, CHART_SLOTS);
  assert.equal(allSeries.length, 8);
  assert.equal(hiddenSeries, 2);
  assert.equal(rows[0].S8, 7);
});

test("orders pie slices largest first and folds the smallest into Other", () => {
  const data = "ABCDEFGH".split("").map((label, i) => ({label, value: 10 - i}));
  const slices = pieSlices(data, "Other");

  assert.equal(slices.length, CHART_SLOTS);
  assert.deepEqual(slices.map((slice) => slice.label), ["A", "B", "C", "D", "E", "Other"]);
  assert.equal(slices.at(-1).value, 5 + 4 + 3);
});

test("leaves a pie that fits the palette whole", () => {
  const slices = pieSlices([{label: "x", value: "2"}, {label: "y", value: 5}], "Other");

  assert.deepEqual(slices, [{label: "y", value: 5}, {label: "x", value: 2}]);
});
