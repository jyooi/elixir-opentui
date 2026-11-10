const loop = { idle: "Not ticking", running: "Ticking", suspended: "Suspended" };

export const title = "Runtime tick loop";

const queue = (v) => Object.values(v.mailbox);

export const state = (v) => {
  const ticks = (v.srv.held === "armed" ? 1 : 0) + v.orphans + queue(v).filter((m) => m === "tick").length;
  const chains = ticks === 0 ? "no tick on the way" : ticks === 1 ? "one tick on the way" : "two or more ticks on the way";
  const due = v.srv.count === 0 && (v.srv.live || v.srv.refs > 0 || v.srv.explicit) ? "ticks wanted" : "no ticks wanted";
  return `${loop[v.srv.control]}, ${chains}, ${due}`;
};

const name = (request) => (request === "event" ? "an event" : request);

export const step = (action, from, to) => {
  if (action === "TimerFires") return "the tick timer fires";
  if (action === "HandleTick") return "the runtime handles a tick message";
  if (queue(to).length > queue(from).length) return `a caller sends ${name(queue(to).at(-1))}`;
  return `the runtime handles ${name(queue(from)[0])}`;
};
