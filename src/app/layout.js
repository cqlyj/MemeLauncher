import { Nabla } from "next/font/google";
import "./globals.css";

const nabla = Nabla({ subsets: ["latin"] });

export const metadata = {
  title: "Meme Launcher",
  description: "Launch your memes!",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className={`$nabla.className`}>{children}</body>
    </html>
  );
}
