import { useEffect, useState } from "react";
import Image from "next/image";
import { ethers } from "ethers";

function Trade({ toggleTrade, meme, provider, launcher }) {
  const [target, setTarget] = useState(0);
  const [limit, setLimit] = useState(0);
  const [cost, setCost] = useState(0);

  async function buyHandler(form) {
    const amount = form.get("amount");

    const cost = await launcher.getCost(meme.sold);
    const totalCost = cost * BigInt(amount);

    const signer = await provider.getSigner();

    const transaction = await launcher
      .connect(signer)
      .buyMeme(meme.meme, ethers.parseUnits(amount, 18), { value: totalCost });
    await transaction.wait();

    toggleTrade();
  }

  async function getSaleDetails() {
    const target = await launcher.getTargetValue();
    setTarget(target);

    const limit = await launcher.getAllowedAmountToBuy();
    setLimit(limit);

    const cost = await launcher.getCost(meme.sold);
    setCost(cost);
  }

  useEffect(() => {
    if (launcher && meme) {
      getSaleDetails();
    }
  }, [launcher, meme]);

  return (
    <div className="trade">
      <h2>trade</h2>

      <div className="token_details">
        <p className="name">{meme.name}</p>
        <p>
          creator:{" "}
          {meme.creator.slice(0, 6) + "..." + meme.creator.slice(38, 42)}
        </p>
        <Image src={meme.image} alt="Pepe" width={256} height={256} />
        <p>marketcap: {ethers.formatUnits(meme.ethRaised, 18)} ETH</p>
        <p>base cost: {ethers.formatUnits(cost, 18)} ETH</p>
      </div>

      {meme.sold >= limit || meme.ethRaised >= target ? (
        <p className="disclaimer">target reached!</p>
      ) : (
        <form action={buyHandler}>
          <input
            type="number"
            name="amount"
            min={1}
            max={10000}
            placeholder="1"
          />
          <input type="submit" value="[ buy ]" />
        </form>
      )}

      <button onClick={toggleTrade} className="btn--fancy">
        [ cancel ]
      </button>
    </div>
  );
}

export default Trade;
