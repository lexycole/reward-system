#[starknet::interface]
pub trait IRewardSystem<TContractState> {
    fn add_reward(ref self: TContractState, user: felt252, amount: u256);
    fn claim_reward(ref self: TContractState, amount: u256);
    fn get_user_balance(self: @TContractState, user: felt252) -> u256;
    fn transfer_rewards(ref self: TContractState, to: felt252, amount: u256);
    fn register_wallet(ref self: TContractState, wallet_address: felt252);
    fn get_registered_wallets(self: @TContractState) -> Array<felt252>;
}

#[starknet::contract]
mod RewardSystem {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use core::array::ArrayTrait;
    use core::traits::Into;
    use core::option::OptionTrait;
    use core::num::traits::Zero;

    #[storage]
    struct Storage {
        user_balances: starknet::storage::Map::<felt252, u256>,
        total_rewards_pool: u256,
        registered_wallets: LegacyMap::<u256, felt252>,
        registered_wallets_count: u256,
        wallet_exists: starknet::storage::Map::<felt252, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RewardAdded: RewardAdded,
        RewardClaimed: RewardClaimed,
        RewardTransferred: RewardTransferred,
        WalletRegistered: WalletRegistered
    }

    #[derive(Drop, starknet::Event)]
    struct RewardAdded {
        user: felt252,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct RewardClaimed {
        user: felt252,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct RewardTransferred {
        from: felt252,
        to: felt252,
        amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct WalletRegistered {
        user: felt252,
        wallet_address: felt252
    }

    #[abi(embed_v0)]
    impl RewardSystemImpl of super::IRewardSystem<ContractState> {
        fn register_wallet(ref self: ContractState, wallet_address: felt252) {
            // Get caller address
            let caller = get_caller_address().into();
            
            // Check if wallet is already registered
            assert(!self.wallet_exists.read(wallet_address), 'Wallet already registered');
            
            // Get current count and increment
            let current_count = self.registered_wallets_count.read();
            
            // Store wallet at the current count index
            self.registered_wallets.write(current_count, wallet_address);
            self.registered_wallets_count.write(current_count + 1);
            
            // Mark wallet as registered
            self.wallet_exists.write(wallet_address, true);
            
            // Emit event
            self.emit(Event::WalletRegistered(WalletRegistered { 
                user: caller, 
                wallet_address 
            }));
        }

        fn get_registered_wallets(self: @ContractState) -> Array<felt252> {
            // Create an array to store wallets
            let mut wallets = ArrayTrait::new();
            
            // Get the total count of registered wallets
            let count = self.registered_wallets_count.read();
            
            // Iterate and collect wallets
            let mut i: u256 = 0;
            loop {
                if i == count {
                    break;
                }
                
                let wallet = self.registered_wallets.read(i);
                wallets.append(wallet);
                
                i += 1;
            };
            
            wallets
        }

        fn add_reward(ref self: ContractState, user: felt252, amount: u256) {
            // Validate input
            assert(amount != 0, 'Reward amount cannot be 0');
            
            // Update user balance
            let current_balance = self.user_balances.read(user);
            self.user_balances.write(user, current_balance + amount);
            
            // Update total rewards pool
            let current_pool = self.total_rewards_pool.read();
            self.total_rewards_pool.write(current_pool + amount);
            
            // Emit event
            self.emit(Event::RewardAdded(RewardAdded { user, amount }));
        }

        fn claim_reward(ref self: ContractState, amount: u256) {
            // Get caller address as felt252
            let caller = get_caller_address().into();
            
            // Check sufficient balance using u256 comparison
            let current_balance = self.user_balances.read(caller);
            assert(current_balance >= amount, 'Insufficient reward balance');
            
            // Update balance
            self.user_balances.write(caller, current_balance - amount);
            
            // Emit event
            self.emit(Event::RewardClaimed(RewardClaimed { user: caller, amount }));
        }

        fn get_user_balance(self: @ContractState, user: felt252) -> u256 {
            self.user_balances.read(user)
        }

        fn transfer_rewards(ref self: ContractState, to: felt252, amount: u256) {
            // Get caller address as felt252
            let caller = get_caller_address().into();
            
            // Improved error handling
            let sender_balance = self.user_balances.read(caller);
            assert(sender_balance >= amount, 'Insufficient balance');
            
            // Update sender and receiver balances
            self.user_balances.write(caller, sender_balance - amount);
            
            let recipient_balance = self.user_balances.read(to);
            self.user_balances.write(to, recipient_balance + amount);
            
            // Emit event
            self.emit(Event::RewardTransferred(RewardTransferred { 
                from: caller, 
                to, 
                amount 
            }));
        }
    }
}