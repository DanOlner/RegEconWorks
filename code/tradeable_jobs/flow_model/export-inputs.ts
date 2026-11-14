// Writes the calibrated spec-v1 parameters and the experiments' scenarios as JSON, for the R port.
import { writeFileSync } from 'node:fs';
import { specV1 } from '../src/params/spec-v1-calibrated';
import { EXPERIMENTS, SHOCK_PERIOD, LAST_PERIOD } from '../src/scenarios/experiments';
const out = process.argv[2] ?? '.';
writeFileSync(`${out}/flow_params_spec_v1.json`, JSON.stringify(specV1(), null, 1));
writeFileSync(`${out}/flow_scenarios.json`, JSON.stringify({ shockPeriod: SHOCK_PERIOD, lastPeriod: LAST_PERIOD,
  experiments: EXPERIMENTS.map((e) => ({ id: e.id, title: e.title, scenario: e.scenario })) }, null, 1));
console.log('Wrote', EXPERIMENTS.length, 'scenarios');
