module protocol::app {
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::transfer;
  use sui::package;
  use x::ac_table::AcTableCap;
  use x::one_time_lock_value::OneTimeLockValue;
  use protocol::market::{Self, Market};
  use protocol::interest_model::{Self, InterestModels, InterestModel};
  use protocol::risk_model::{Self, RiskModels, RiskModel};

  /// OTW
  struct APP has drop {}

  struct AdminCap has key, store {
    id: UID,
    interest_model_cap: AcTableCap<InterestModels>,
    risk_model_cap: AcTableCap<RiskModels>
  }
  
  fun init(otw: APP, ctx: &mut TxContext) {
    init_internal(otw, ctx)
  }
  
  #[test_only]
  public fun init_t(otw: APP, ctx: &mut TxContext) {
    init_internal(otw, ctx)
  }
  
  fun init_internal(otw: APP, ctx: &mut TxContext) {
    let (market, interest_model_cap, risk_model_cap) = market::new(ctx);
    let adminCap = AdminCap {
      id: object::new(ctx),
      interest_model_cap,
      risk_model_cap
    };
    package::claim_and_keep(otw, ctx);
    transfer::public_share_object(market);
    transfer::transfer(adminCap, tx_context::sender(ctx));
  }

  /// For extension of the protocol
  public fun market_uid_mut(
    _: &AdminCap,
    market: &mut Market,
  ): &mut UID {
    market::uid_mut(market)
  }
  
  public fun create_interest_model_change<T>(
    admin_cap: &AdminCap,
    base_rate_per_sec: u64,
    low_slope: u64,
    kink: u64,
    high_slope: u64,
    revenue_factor: u64,
    scale: u64,
    min_borrow_amount: u64,
    borrow_weight: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<InterestModel> {
    let interest_model_change = interest_model::create_interest_model_change<T>(
      &admin_cap.interest_model_cap,
      base_rate_per_sec,
      low_slope,
      kink,
      high_slope,
      revenue_factor,
      scale,
      min_borrow_amount,
      borrow_weight,
      ctx,
    );
    interest_model_change
  }
  public fun add_interest_model<T>(
    market: &mut Market,
    admin_cap: &AdminCap,
    interest_model_change: &mut OneTimeLockValue<InterestModel>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let now = clock::timestamp_ms(clock) / 1000;
    let interest_models = market::interest_models_mut(market);
    interest_model::add_interest_model<T>(
      interest_models,
      &admin_cap.interest_model_cap,
      interest_model_change,
      ctx
    );
    market::register_coin<T>(market, now);
  }

  public fun create_risk_model_change<T>(
    admin_cap: &AdminCap,
    collateral_factor: u64, // exp. 70%,
    liquidation_factor: u64, // exp. 80%,
    liquidation_penalty: u64, // exp. 7%,
    liquidation_discount: u64, // exp. 5%,
    scale: u64,
    max_collateral_amount: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<RiskModel> {
    let risk_model_change = risk_model::create_risk_model_change<T>(
      &admin_cap.risk_model_cap,
      collateral_factor, // exp. 70%,
      liquidation_factor, // exp. 80%,
      liquidation_penalty, // exp. 7%,
      liquidation_discount, // exp. 5%,
      scale,
      max_collateral_amount,
      ctx
    );
    risk_model_change
  }
  
  public entry fun add_risk_model<T>(
    market: &mut Market,
    admin_cap: &AdminCap,
    risk_model_change: &mut OneTimeLockValue<RiskModel>,
    ctx: &mut TxContext
  ) {
    let risk_models = market::risk_models_mut(market);
    risk_model::add_risk_model<T>(
      risk_models,
      &admin_cap.risk_model_cap,
      risk_model_change,
      ctx
    );
    market::register_collateral<T>(market);
  }

  public entry fun add_limiter<T>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    outflow_limit: u64,
    outflow_cycle_duration: u32,
    outflow_segment_duration: u32,
    _ctx: &mut TxContext
  ) {
    market::add_limiter<T>(
      market,
      outflow_limit,
      outflow_cycle_duration,
      outflow_segment_duration,
    );
  }

  public entry fun update_outflow_segment_params<T>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    outflow_cycle_duration: u32,
    outflow_segment_duration: u32,
    _ctx: &mut TxContext
  ) {
    market::update_outflow_segment_params<T>(
      market,
      outflow_cycle_duration,
      outflow_segment_duration,
    );
  }

  public entry fun update_outflow_limit_params<T>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    outflow_limit: u64,
    _ctx: &mut TxContext
  ) {
    market::update_outflow_limit_params<T>(
      market,
      outflow_limit,
    );
  }
}
