declare module 'opossum' {
  export interface CircuitBreakerOptions {
    timeout?: number;
    errorThresholdPercentage?: number;
    resetTimeout?: number;
    capacity?: number;
    name?: string;
  }
  export class CircuitBreaker<T = unknown> {
    constructor(fn: (payload: string) => Promise<T>, options?: CircuitBreakerOptions);
    fire(...args: unknown[]): Promise<T>;
    open: boolean;
    closed: boolean;
    stats: Record<string, number>;
    on(event: string, cb: (...args: unknown[]) => void): this;
    shutdown(): void;
  }
  export default CircuitBreaker;
}
