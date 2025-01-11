import { ethers } from "ethers";
import Image from "next/image";

function Meme({ toggleTrade, meme }) {
  return (
    <button onClick={() => toggleTrade(meme)} className="token">
      <div>
        <Image src={meme.image} alt="meme image" width={256} height={256} />
        <p>
          created by{" "}
          {meme.creator.slice(0, 6) + "..." + meme.creator.slice(38, 42)}
        </p>
        <p>market Cap: {ethers.formatUnits(meme.ethRaised, 18)} eth</p>
        <p className="name">{meme.name}</p>
      </div>
    </button>
  );
}

export default Meme;
