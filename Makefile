-include .env

help:
	@echo "Usage: make <target>"

all: install build

install:
	@forge install OpenZeppelin/openzeppelin-contracts --no-commit && forge install uniswap/v4-core --no-commit && forge install uniswap/v4-periphery --no-commit

build:
	@forge build && forge inspect src/contracts/Launcher.sol:Launcher abi > abi/Launcher.json 

deploy-anvil:
	@forge script script/DeployLauncher.s.sol:DeployLauncher --rpc-url $(ANVIL_RPC_URL) --private-key $(DEFAULT_ANVIL_PRIVATE_KEY) --broadcast -vvvv

deploy-amoy:
	@forge script script/DeployLauncher.s.sol:DeployLauncher --rpc-url $(AMOY_RPC_URL) --account burner --sender $(BURNER_ADDRESS) --verify --etherscan-api-key $(AMOYSCAN_API_KEY) --broadcast -vvvv

create-meme-anvil:
	@forge script script/CreateMeme.s.sol:CreateMeme --rpc-url $(ANVIL_RPC_URL) --private-key $(DEFAULT_ANVIL_PRIVATE_KEY) --broadcast -vvvv

create-meme-amoy:
	@forge script script/CreateMeme.s.sol:CreateMeme --rpc-url $(AMOY_RPC_URL) --account burner --sender $(BURNER_ADDRESS) --verify --etherscan-api-key $(AMOYSCAN_API_KEY) --broadcast -vvvv

withdraw-fee-anvil:
	@forge script script/WithdrawFee.s.sol:WithdrawFee --rpc-url $(ANVIL_RPC_URL) --private-key $(DEFAULT_ANVIL_PRIVATE_KEY) --broadcast -vvvv

withdraw-fee-amoy:
	@forge script script/WithdrawFee.s.sol:WithdrawFee --rpc-url $(AMOY_RPC_URL) --account burner --sender $(BURNER_ADDRESS) --verify --etherscan-api-key $(AMOYSCAN_API_KEY) --broadcast -vvvv

buy-meme-anvil:
	@forge script script/BuyMeme.s.sol:BuyMeme --rpc-url $(ANVIL_RPC_URL) --private-key $(DEFAULT_ANVIL_PRIVATE_KEY) --broadcast -vvvv

buy-meme-amoy:
	@forge script script/BuyMeme.s.sol:BuyMeme --rpc-url $(AMOY_RPC_URL) --account burner --sender $(BURNER_ADDRESS) --verify --etherscan-api-key $(AMOYSCAN_API_KEY) --broadcast -vvvv

launch-meme-anvil:
	@forge script script/LaunchMeme.s.sol:LaunchMeme --rpc-url $(ANVIL_RPC_URL) --private-key $(DEFAULT_ANVIL_PRIVATE_KEY) --broadcast -vvvv

launch-meme-amoy:
	@forge script script/LaunchMeme.s.sol:LaunchMeme --rpc-url $(AMOY_RPC_URL) --account burner --sender $(BURNER_ADDRESS) --verify --etherscan-api-key $(AMOYSCAN_API_KEY) --broadcast -vvvv

slither:
	@slither . --config-file slither.config.json